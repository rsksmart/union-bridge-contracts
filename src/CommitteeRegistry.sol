// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import "forge-std/console.sol";

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {BaseProxy} from "./BaseProxy.sol";
import {
    Role,
    Member,
    CommitteeMember,
    Committee,
    ICommitteeRegistry,
    PendingCommittee,
    PendingCommitteeData,
    PendingCommitteeStatus,
    PublicKeyIndex,
    PublicKeyRegistration,
    PUBLIC_KEYS_INDEX_LENGTH,
    ApplicationData
} from "./interfaces/ICommitteeRegistry.sol";
import {StreamDenomination, IStreamManager} from "./interfaces/IStreamManager.sol";
import {IPegManager} from "./interfaces/IPegManager.sol";

contract CommitteeRegistry is ICommitteeRegistry, BaseProxy {
    // Address of the Memeber => Amount provided
    Member[] internal members;

    uint256 public constant MAX_COMMITTEES_SIZE = 100;
    uint256 public constant MAX_MEMBERS_SIZE = 256;
    uint256 public constant MAX_MEMBERS_PER_COMMITTEE = 100;

    // Committee selection constants
    uint256 public constant MIN_WATCHTOWERS = 3;
    uint256 public constant MIN_OPERATORS = 3;
    // NOTE: Should fit condition MIN_COMMITTEE_MEMBERS > MIN_WATCHTOWERS + MIN_OPERATORS
    uint256 public constant MIN_COMMITTEE_MEMBERS = 10;

    mapping(uint64 streamId => PendingCommittee) internal pendingCommittees;
    mapping(uint256 committeeId => Committee) internal committeesByKey;
    mapping(uint64 streamId => bool createCommittee) internal shouldCreateCommittee;

    // NOTE: This is a mapping of the members, where the key is the address and the value is the index in the members array + 1
    mapping(address => uint16) internal memberIndexByAddress;
    IStreamManager streamManager;
    IPegManager pegManager;

    uint256 public pendingCommitteeTimeout;

    mapping(StreamDenomination denomination => mapping(Role role => uint16[] membersIndex)) internal
        committeesCandidates;

    function initialize(address _initialOwner) public virtual initializer {
        __BaseProxy_init(_initialOwner);
        pendingCommitteeTimeout = 1 days; // Default timeout for pending committees
        for (uint64 i = 0; i <= uint64(StreamDenomination._10BTC); i++) {
            shouldCreateCommittee[i] = true;
        }
    }

    function getMinimumDeposit(StreamDenomination _denomination) public view returns (uint256) {
        return streamManager.getStreamById(uint64(_denomination)).securityBondValue;
    }

    function _initMemberBalance(Member storage _member) internal {
        uint64 streamsLength = streamManager.getStreamsLength();
        _member.balance.available = 0;
        for (uint256 i = 0; i < streamsLength; i++) {
            _member.balance.staked.push();
            _member.balance.applications.push(ApplicationData({requestedRole: Role.None, preStaked: 0}));
        }
    }

    function _getMemberTakePubKeyByIndex(uint16 _memberIndex) internal view returns (bytes32) {
        return members[_memberIndex].publicKeys[uint8(PublicKeyIndex.Take)];
    }

    function _getMemberPubKeyByAddress(address _address) internal view returns (bytes32) {
        uint16 memberIndex = memberIndexByAddress[_address];
        if (memberIndex == 0) {
            return bytes32(0);
        }
        // Substract 1 to get the correct index
        return members[memberIndex - 1].publicKeys[uint8(PublicKeyIndex.Take)];
    }

    function _getOrRegisterMember(address _address, PublicKeyRegistration[] calldata _publicKeys)
        internal
        returns (Member storage)
    {
        uint16 memberIndex = memberIndexByAddress[_address];
        Member storage member;
        // Check if the member is already registered
        if (memberIndex == 0) {
            member = _registerMember(_publicKeys);
        } else {
            // Already exists, get the member from the members array
            member = members[memberIndex - 1];
            // Check if the public keys are the same as the stored member's public keys
            for (uint8 i = 0; i < PUBLIC_KEYS_INDEX_LENGTH; i++) {
                if (member.publicKeys[i] != _publicKeys[i].publicKeyX) {
                    revert PublicKeyMismatch(i, member.publicKeys[i], _publicKeys[i].publicKeyX);
                }
            }
        }
        return member;
    }

    function applyToStream(StreamDenomination _stream, Role _role, PublicKeyRegistration[] calldata _publicKeys)
        external
        payable
    {
        if (_role == Role.None) {
            revert RequestedNoneRoleForStream(_stream);
        }
        // If the public keys length is not the same as the enum length revert
        uint256 publicKeysLength = _publicKeys.length;
        if (publicKeysLength != PUBLIC_KEYS_INDEX_LENGTH) {
            revert InvalidPublicKeysLength(publicKeysLength, PUBLIC_KEYS_INDEX_LENGTH);
        }

        Member storage member = _getOrRegisterMember(msg.sender, _publicKeys);

        if (_role == Role.None) {
            revert RequestedNoneRoleForStream(_stream);
        }
        if (member.balance.applications[uint8(_stream)].requestedRole != Role.None) {
            revert MemberAlreadyRegisteredForStream(
                msg.sender, _stream, _role, member.balance.applications[uint8(_stream)].requestedRole
            );
        }
        uint256 minDeposit = getMinimumDeposit(_stream);
        if (msg.value < minDeposit) {
            revert DespositBondTooLow(msg.value, minDeposit);
        }

        _registerCandidateToStream(msg.sender, _stream, _role, msg.value);
        emit NewSecurityBondDeposit(msg.sender, _stream, _role, msg.value);

        _createCommitteeAfterApplyToStream(_stream);
    }

    // NOTE: This function intends to keep many different structures in sync, be careful when modifying it
    function _registerCandidateToStream(address _memberAddress, StreamDenomination _stream, Role _role, uint256 _amount)
        internal
    {
        Member storage member = _getMemberByAddress(_memberAddress);

        member.balance.applications[uint8(_stream)].preStaked = _amount;
        member.balance.applications[uint8(_stream)].requestedRole = _role;

        committeesCandidates[_stream][_role].push(_getMemberIndexByAddress(msg.sender));
    }

    function unsubscribeFromStream(StreamDenomination _denomination) external {
        Member storage member = _getMemberByAddress(msg.sender);
        Role role = member.balance.applications[uint8(_denomination)].requestedRole;

        if (role == Role.None) {
            revert MemberIsNotCandidateForStream(msg.sender, _denomination);
        }
        _removeCandidateAndUpdateBalance(_getMemberIndexByAddress(msg.sender), _denomination, false, 0);
    }

    // NOTE: This function intends to keep many different structures in sync, be careful when modifying it
    // This function is used to remove a candidate from the committees candidates list and update the member's balance accordingly.
    // _newCommittee is used to determine if the candidate is being removed because it's part of a new committee or unsubscribe.
    // If _newCommittee is false, _packetNumber is ignored
    function _removeCandidateAndUpdateBalance(
        uint16 _memberIndex,
        StreamDenomination _denomination,
        bool _newCommittee,
        uint64 _packetNumber
    ) internal {
        Member storage member = members[_memberIndex];
        Role role = member.balance.applications[uint8(_denomination)].requestedRole;
        uint256 preStakedAmount = member.balance.applications[uint8(_denomination)].preStaked;

        _removeFromCommitteesCandidates(_memberIndex, _denomination, role);

        member.balance.applications[uint8(_denomination)] = ApplicationData({requestedRole: Role.None, preStaked: 0});

        if (_newCommittee) {
            // Save the pre-staked amount to the staked balance
            member.balance.staked[uint8(_denomination)][_packetNumber] = preStakedAmount;
        } else {
            member.balance.available += preStakedAmount;
            emit NewAvailableBalance(
                member.publicKeys[uint256(PublicKeyIndex.Take)], member.balance.available, preStakedAmount
            );
        }
    }

    function _updateCommitteeCandidates(
        CommitteeMember[] memory _members,
        StreamDenomination _denomination,
        uint64 _packetNumber
    ) internal {
        for (uint256 i = 0; i < _members.length; i++) {
            _removeCandidateAndUpdateBalance(_members[i].index, _denomination, true, _packetNumber);
        }
    }

    function _removeFromCommitteesCandidates(uint16 _memberIndex, StreamDenomination _stream, Role _role) internal {
        uint16[] storage candidates = committeesCandidates[_stream][_role];
        uint256 length = candidates.length;

        // NOTE: This effectively brings the last candidate forward in the list by replacing the removed member
        for (uint256 i = 0; i < length; i++) {
            if (candidates[i] == _memberIndex) {
                candidates[i] = candidates[length - 1];
                candidates.pop();
                emit MemberUnsubscribedFromStream(msg.sender, _stream);
                break;
            }
        }
    }

    function withdrawAvailableBalance() external {
        Member storage member = _getMemberByAddress(msg.sender);
        uint256 amount = member.balance.available;
        if (amount == 0) {
            revert NoAvailableBalanceToWithdraw(msg.sender);
        }
        member.balance.available = 0;
        emit AvailableBalanceRetrieved(msg.sender, amount);

        (bool sent,) = msg.sender.call{value: amount}("");
        if (!sent) {
            revert FailedToSendRSK(msg.sender, amount);
        }
    }

    function _getAddressFromPublicKey(bytes memory _uncompressedPublicKey) internal pure returns (address) {
        return address(uint160(uint256(keccak256(_uncompressedPublicKey))));
    }

    function _validatePublicKeys(PublicKeyRegistration[] calldata _publicKeys) internal pure {
        // Iterate over the public keys to check if they are valid
        for (uint8 i = 0; i < PUBLIC_KEYS_INDEX_LENGTH; i++) {
            // Check if the public key X is not repeated
            for (uint8 j = i + 1; j < PUBLIC_KEYS_INDEX_LENGTH; j++) {
                if (_publicKeys[i].publicKeyX == _publicKeys[j].publicKeyX) {
                    revert RepeatedPublicKeys(i, _publicKeys[i].publicKeyX, j, _publicKeys[j].publicKeyX);
                }
            }

            // Check if the public keys is not 0
            if (_publicKeys[i].publicKeyX == bytes32(0) || _publicKeys[i].publicKeyY == bytes32(0)) {
                revert InvalidZeroPublicKey(i, _publicKeys[i].publicKeyX, _publicKeys[i].publicKeyY);
            }

            // Validate signature is not zero
            if (_publicKeys[i].v == 0 || _publicKeys[i].r == bytes32(0) || _publicKeys[i].s == bytes32(0)) {
                revert InvalidZeroSignature(i, _publicKeys[i]);
            }

            // Use the uncompressed public key as the message
            bytes memory uncompressedPublicKey = abi.encode(_publicKeys[i].publicKeyX, _publicKeys[i].publicKeyY);
            bytes32 messageHash = keccak256(uncompressedPublicKey);

            // Validate the signature for the message is valid
            // * The `ecrecover` EVM precompile allows for malleable (non-unique) signatures:
            // * this function rejects them by requiring the `s` value to be in the lower
            // * half order, and the `v` value to be either 27 or 28.
            address recoveredSignerAddress =
                ECDSA.recover(messageHash, _publicKeys[i].v, _publicKeys[i].r, _publicKeys[i].s);

            // Get the expectedsigner address from the uncompressed public key
            address expectedSignerAddress = _getAddressFromPublicKey(uncompressedPublicKey);

            // Validate the recovered signer address is the same as the expected signer address
            if (recoveredSignerAddress != expectedSignerAddress) {
                revert InvalidSignature(i, _publicKeys[i], recoveredSignerAddress, expectedSignerAddress);
            }
        }
    }

    function _registerMember(PublicKeyRegistration[] calldata _publicKeys) internal returns (Member storage) {
        // Check max Members
        if (members.length >= MAX_MEMBERS_SIZE) {
            revert TooManyMembers(MAX_MEMBERS_SIZE);
        }
        // Check if the public keys and the signatures associated are valid
        _validatePublicKeys(_publicKeys);

        members.push(); // Expand the array
        Member storage member = members[members.length - 1]; // Get reference
        // Initialize Member public keys
        for (uint8 i = 0; i < PUBLIC_KEYS_INDEX_LENGTH; i++) {
            member.publicKeys.push(_publicKeys[i].publicKeyX);
        }
        _initMemberBalance(member);
        // We save the position in the array + 1, to avoid 0 as a valid index, it is then substracted in getMemberPubKeyByAddress
        memberIndexByAddress[msg.sender] = uint16(members.length);

        emit NewMember(member.publicKeys);
        return member;
    }

    function _registerCommittee(uint256 _committeeId, Committee storage _committee) internal {
        committeesByKey[_committeeId] = _committee;
        emit NewCommittee(_committeeId, _committee);
    }

    function getCommittee(uint256 _committeeId) public view returns (Committee memory) {
        Committee memory committee = committeesByKey[_committeeId];
        if (committee.memberIndexesAndRoles.length == 0) {
            revert CommitteeNotFound(_committeeId);
        }
        return committee;
    }

    function getMembersLength() external view returns (uint256) {
        return members.length;
    }

    function getCommitteeMembers(uint256 _committeeId) external view returns (CommitteeMember[] memory) {
        return getCommittee(_committeeId).memberIndexesAndRoles;
    }

    function getMemberTakePubKeyByIndex(uint16 _memberIndex) external view returns (bytes32) {
        if (_memberIndex >= members.length) {
            revert MemberIndexNotFound(_memberIndex);
        }
        return _getMemberTakePubKeyByIndex(_memberIndex);
    }

    function getMemberIndexByAddress(address _address) external view returns (uint16) {
        return _getMemberIndexByAddress(_address);
    }

    function _getMemberIndexByAddress(address _address) internal view returns (uint16) {
        uint16 memberIndex = memberIndexByAddress[_address];

        // 0 is reserved for non registered members
        if (memberIndex == 0) {
            revert MemberNotRegistered(_address);
        }
        if (memberIndex > members.length) {
            revert _MemberIndexOutOfBounds(memberIndex);
        }

        // Substract 1 to get the correct index
        return memberIndex - 1;
    }

    function getMemberPublicKeys(address _address) external view returns (bytes32[] memory publicKeys) {
        Member storage member = _getMemberByAddress(_address);
        publicKeys = new bytes32[](PUBLIC_KEYS_INDEX_LENGTH);
        for (uint8 i = 0; i < PUBLIC_KEYS_INDEX_LENGTH; i++) {
            publicKeys[i] = member.publicKeys[i];
        }
        return publicKeys;
    }

    function getMemberRequestedRole(address _address, StreamDenomination _denomination) external view returns (Role) {
        return _getMemberByAddress(_address).balance.applications[uint8(_denomination)].requestedRole;
    }

    function getMemberAvailableBalance(address _address) external view returns (uint256) {
        return _getMemberByAddress(_address).balance.available;
    }

    function getMemberPreStakedBalance(address _address, StreamDenomination _denomination)
        external
        view
        returns (uint256)
    {
        return _getMemberByAddress(_address).balance.applications[uint8(_denomination)].preStaked;
    }

    function getMemberStakedBalance(address _address, StreamDenomination _denomination, uint64 _packetNumber)
        external
        view
        returns (uint256 amount)
    {
        return _getMemberByAddress(_address).balance.staked[uint8(_denomination)][_packetNumber];
    }

    function _getMemberByAddress(address _address) internal view returns (Member storage) {
        uint16 memberIndex = memberIndexByAddress[_address];

        // 0 is reserved for non registered members
        if (memberIndex == 0) {
            revert NonRegisteredMember(_address);
        }

        // Substract 1 to get the correct index
        return members[memberIndex - 1];
    }

    function restartPendingCommittee(uint64 _streamId) external {
        uint256 createdAt = pendingCommittees[_streamId].createdAt;
        if (createdAt == 0) {
            revert CommitteeIsNotPending(_streamId);
        }

        // slither-disable-next-line timestamp
        if (block.timestamp < createdAt + pendingCommitteeTimeout) {
            // This is called from the pegManager, so we should not revert.
            revert PendingCommitteeNotExpired(_streamId, createdAt, createdAt + pendingCommitteeTimeout);
        }

        _slashCommittee();
        _deletePendingCommittee(_streamId);
        _createCommittee(_streamId);
    }

    function createCommittee(uint64 _streamId) external onlyPegManager {
        // NOTE: This method is called from the pegManager, so we should not revert.

        uint256 createdAt = pendingCommittees[_streamId].createdAt;
        if (createdAt != 0) {
            // slither-disable-next-line timestamp
            if (block.timestamp < createdAt + pendingCommitteeTimeout) {
                return;
            }

            _slashCommittee();
            _deletePendingCommittee(_streamId);
        }
        _createCommittee(_streamId);
    }

    function _createCommitteeAfterApplyToStream(StreamDenomination _denomination) internal {
        // Cases where we should execute:
        // - Pending committee is expired
        // - Current packet pointer has not a committee
        uint64 streamId = uint64(_denomination);

        if (_createCommitteeIfPending(streamId)) {
            // If there is a pending committee, we should not create a new one at least it's expired
            return;
        }

        if (shouldCreateCommittee[streamId]) {
            _createCommittee(streamId);
        }
    }

    function _createCommitteeIfPending(uint64 _streamId) internal returns (bool) {
        // This function return true if there is a pending committee
        // If there is a pending committee, we should not create a new one at least it's expired
        uint256 createdAt = pendingCommittees[_streamId].createdAt;
        if (createdAt == 0) {
            return false;
        }

        // slither-disable-next-line timestamp
        if (block.timestamp >= createdAt + pendingCommitteeTimeout) {
            _slashCommittee();
            _deletePendingCommittee(_streamId);
            _createCommittee(_streamId);
        }

        return true;
    }

    function _createCommittee(uint64 _streamId) internal returns (PendingCommitteeStatus) {
        // NOTE: This method is called from the pegManager, so we should not revert.
        (CommitteeMember[] memory committeeMembers, PendingCommitteeStatus status) = _selectCommittee(_streamId);
        if (status != PendingCommitteeStatus.Success) {
            shouldCreateCommittee[_streamId] = true;
            return status;
        }

        shouldCreateCommittee[_streamId] = false;
        pendingCommittees[_streamId].createdAt = block.timestamp;
        pendingCommittees[_streamId].missingData = uint16(committeeMembers.length);

        // Initialize the committee members here.
        // No need to initialize aggregatedKey, since it will be set by the members.
        for (uint256 i = 0; i < committeeMembers.length; i++) {
            // Copy committee members from memory to storage
            pendingCommittees[_streamId].committee.memberIndexesAndRoles.push(committeeMembers[i]);

            bytes32 memberPubKey = _getMemberTakePubKeyByIndex(committeeMembers[i].index);
            // Initialize committee users pending data
            pendingCommittees[_streamId].data[memberPubKey] =
                PendingCommitteeData({inCommittee: true, aggregatedKey: bytes32(0)});
        }
        emit NewPendingCommittee(_streamId, pendingCommittees[_streamId].committee);
        return PendingCommitteeStatus.Success;
    }

    function depositMemberInfoForCommittee(uint64 _streamId, bytes32 _aggregatedKey) external {
        PendingCommittee storage pendingCommittee = pendingCommittees[_streamId];
        if (pendingCommittee.createdAt == 0) {
            revert CommitteeIsNotPending(_streamId);
        }

        if (_aggregatedKey == bytes32(0)) {
            revert InvalidAgregatedKey();
        }

        bytes32 memberPubKey = _getCurrentMemberPubKey();
        if (!pendingCommittee.data[memberPubKey].inCommittee) {
            revert MemberNotInCommittee(memberPubKey);
        }

        if (pendingCommittee.data[memberPubKey].aggregatedKey != bytes32(0)) {
            revert MemberAlreadyUpdated(memberPubKey);
        }

        pendingCommittee.data[memberPubKey].aggregatedKey = _aggregatedKey;

        if (pendingCommittee.committee.aggregatedKey == bytes32(0)) {
            // Save the agregated key for the committee
            pendingCommittee.committee.aggregatedKey = _aggregatedKey;
        } else {
            if (pendingCommittee.committee.aggregatedKey != _aggregatedKey) {
                _deletePendingCommittee(_streamId);
                _createCommittee(_streamId); // Ignoring checks
                return;
            }
        }

        pendingCommittee.missingData--;
        if (pendingCommittee.missingData != 0) {
            // Committee is not completed yet
            return;
        }

        // Create unique committee id associated to the streamId and packetNumber.
        uint64 packetNumber = streamManager.getPacketsLength(_streamId);
        uint256 committeeId = uint256(keccak256(abi.encode(_streamId, packetNumber)));
        _updateCommitteeCandidates(
            pendingCommittee.committee.memberIndexesAndRoles, StreamDenomination(_streamId), packetNumber
        );
        _registerCommittee(committeeId, pendingCommittee.committee);
        // create new packet
        streamManager.createNewPacket(_streamId, committeeId, pendingCommittee.committee.aggregatedKey);
        _deletePendingCommittee(_streamId);
    }

    function _slashCommittee() internal {
        // TODO: slash the members. Sasasaaa.
    }

    function getPendingCommittee(uint64 _streamId)
        public
        view
        returns (Committee memory committee, uint256 createdAt, uint256 missingData)
    {
        PendingCommittee storage pendingCommittee = pendingCommittees[_streamId];
        if (pendingCommittee.createdAt == 0) {
            revert CommitteeIsNotPending(_streamId);
        }
        committee = pendingCommittee.committee;
        createdAt = pendingCommittee.createdAt;
        missingData = pendingCommittee.missingData;
    }

    function _getCurrentMemberPubKey() internal view returns (bytes32) {
        bytes32 memberPubKey = _getMemberPubKeyByAddress(msg.sender);
        if (memberPubKey == bytes32(0)) {
            revert MemberNotFound(msg.sender);
        }
        return memberPubKey;
    }

    function isPendingCommitteeExpired(uint64 _streamId) external view returns (bool) {
        uint256 createdAt = pendingCommittees[_streamId].createdAt;
        // If no pending committee in proccess we return false
        if (createdAt == 0) {
            return false;
        }
        // slither-disable-next-line timestamp
        return block.timestamp >= createdAt + pendingCommitteeTimeout;
    }

    function _deletePendingCommittee(uint64 _streamId) internal {
        CommitteeMember[] storage committeeMembers = pendingCommittees[_streamId].committee.memberIndexesAndRoles;
        for (uint256 i = 0; i < committeeMembers.length; i++) {
            bytes32 memberPubKey = _getMemberTakePubKeyByIndex(committeeMembers[i].index);
            delete pendingCommittees[_streamId].data[memberPubKey];
        }
        //slither-disable-next-line mapping-deletion
        delete pendingCommittees[_streamId];
    }

    function getCommitteeCandidates(StreamDenomination _denomination, Role _role)
        external
        view
        returns (uint16[] memory)
    {
        return committeesCandidates[_denomination][_role];
    }

    /**
     * @notice Randomly selects members to form a new committee for a given stream
     * @dev Pseudo-randomly select at least MIN_WATCHTOWERS watchtowers and MIN_OPERATORS operators.
     * - reverts with notEnoughWatchtowers if there are fewer than MIN_WATCHTOWERS watchtower candidates
     * - reverts with notEnoughOperators if there are fewer than MIN_OPERATORS operator candidates
     *
     * @param _streamId The ID of the stream to select committee members for (0-4)
     * @return An array of MIN_COMMITTEE_MEMBERS CommitteeMembers containing the selected members.
     *
     */
    function _selectCommittee(uint64 _streamId) internal returns (CommitteeMember[] memory, PendingCommitteeStatus) {
        // Get the stream denomination for the streamId
        StreamDenomination denomination = StreamDenomination(_streamId);

        // Get candidates per role.
        uint16[] memory watchtowers = committeesCandidates[denomination][Role.Watchtower];
        uint16[] memory operators = committeesCandidates[denomination][Role.Operator];
        uint256 watchtowersLength = watchtowers.length;
        uint256 operatorsLength = operators.length;

        // Ensure we have enough candidates
        if (watchtowersLength < MIN_WATCHTOWERS) {
            emit MissingWatchtowers(denomination, MIN_WATCHTOWERS, MIN_WATCHTOWERS - watchtowersLength);
            return (new CommitteeMember[](0), PendingCommitteeStatus.NotEnoughWatchtowers);
        }

        if (operatorsLength < MIN_OPERATORS) {
            emit MissingOperators(denomination, MIN_OPERATORS, MIN_OPERATORS - operatorsLength);
            return (new CommitteeMember[](0), PendingCommitteeStatus.NotEnoughOperators);
        }

        // Check if we have enough total members for the committee
        uint256 totalAvailableMembers = operatorsLength + watchtowersLength;
        if (totalAvailableMembers < MIN_COMMITTEE_MEMBERS) {
            emit MissingMembers(denomination, MIN_COMMITTEE_MEMBERS, MIN_COMMITTEE_MEMBERS - totalAvailableMembers);
            return (new CommitteeMember[](0), PendingCommitteeStatus.NotEnoughMembers);
        }

        // Amount of each members per role in the committee
        // NOTE: Here assumme that MIN_COMMITTEE_MEMBERS > MIN_WATCHTOWERS + MIN_OPERATORS
        uint256 operatorsCommitteeAmount = (MIN_COMMITTEE_MEMBERS - MIN_WATCHTOWERS > operatorsLength)
            ? operatorsLength
            : MIN_COMMITTEE_MEMBERS - MIN_WATCHTOWERS;
        uint256 watchtowerCommitteeAmount = MIN_COMMITTEE_MEMBERS - operatorsCommitteeAmount;
        uint256 committeeMembersCounter = 0;

        // Create the final committee with MIN_COMMITTEE_MEMBERS members
        CommitteeMember[] memory selectedMembers = new CommitteeMember[](MIN_COMMITTEE_MEMBERS);

        // True randomness is not required here. We only need enough unpredictability to ensure
        // different committee members get selected across multiple runs.
        // We use Fisher-Yates shuffle because it guarantees each index is selected exactly once.
        // This way we avoid index collisions and infinite loops.

        // Select random operators
        for (uint256 length = operatorsLength; length > operatorsLength - operatorsCommitteeAmount; length--) {
            // slither-disable-next-line weak-prng
            uint256 randomPos = uint256(keccak256(abi.encode(block.timestamp, length))) % length;

            // This indexing will be simplified when `candidates` array is split in `watchtowers` and `operators` arrays
            selectedMembers[committeeMembersCounter++] =
                CommitteeMember({index: operators[randomPos], role: Role.Operator});

            // Just move last position to replace random position. There is no need to swap values now.
            operators[randomPos] = operators[length - 1];
        }

        // Select random watchtowers
        for (uint256 length = watchtowersLength; length > watchtowersLength - watchtowerCommitteeAmount; length--) {
            // slither-disable-next-line weak-prng
            uint256 randomPos = uint256(keccak256(abi.encode(block.timestamp, length))) % length;

            // This indexing will be simplified when `candidates` array is split in `watchtowers` and `operators` arrays
            selectedMembers[committeeMembersCounter++] =
                CommitteeMember({index: watchtowers[randomPos], role: Role.Watchtower});

            // Just move last position to replace random position. There is no need to swap values now.
            watchtowers[randomPos] = watchtowers[length - 1];
        }

        return (selectedMembers, PendingCommitteeStatus.Success);
    }

    function setPendingCommitteeTimeout(uint256 _timeout) external onlyOwner {
        if (_timeout == 0) {
            revert InvalidZeroTimeout();
        }
        pendingCommitteeTimeout = _timeout;
    }

    function setStreamManager(IStreamManager _streamManager) public onlyOwner {
        if (address(_streamManager) == address(0)) {
            revert InvalidZeroAddress();
        }
        streamManager = _streamManager;
    }

    function setPegManager(IPegManager _pegManager) external onlyOwner {
        if (address(_pegManager) == address(0)) {
            revert InvalidZeroAddress();
        }
        pegManager = _pegManager;
    }

    /// ==== Modifiers ====
    modifier onlyPegManager() {
        if (address(pegManager) != msg.sender) {
            revert UnauthorizedAccount(msg.sender);
        }
        _;
    }
}
