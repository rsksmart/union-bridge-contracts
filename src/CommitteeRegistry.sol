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
    mapping(address => Member) internal members;

    uint256 public constant MAX_COMMITTEES_SIZE = 100;
    uint256 public constant MAX_MEMBERS_PER_COMMITTEE = 100;

    // Committee selection constants
    uint256 public minCommitteeWatchtowers;
    uint256 public minCommitteeOperators;
    uint256 public minCommitteeMembers;

    mapping(uint64 streamId => PendingCommittee) internal pendingCommittees;
    mapping(uint256 committeeId => Committee) internal committeesByKey;
    mapping(uint64 streamId => bool createCommittee) internal shouldCreateCommittee;

    IStreamManager streamManager;
    IPegManager pegManager;

    uint256 public pendingCommitteeTimeout;
    uint256 public bannedMemberTimeout;

    uint256 public slashingPercentage;
    uint256 public rewardPercentage;

    // This variable is used to track the contract collected rewards available.
    uint256 public contractAvailableBalance;

    mapping(StreamDenomination denomination => mapping(Role role => address[] membersAddress)) internal
        committeesCandidates;

    function initialize(address _initialOwner) public virtual initializer {
        __BaseProxy_init(_initialOwner);
        for (uint64 i = 0; i <= uint64(StreamDenomination._10BTC); i++) {
            shouldCreateCommittee[i] = true;
        }

        pendingCommitteeTimeout = 1 days; // Default timeout for pending committees
        bannedMemberTimeout = 7 days;

        minCommitteeWatchtowers = 3;
        minCommitteeOperators = 3;
        minCommitteeMembers = 10;

        slashingPercentage = 40;
        rewardPercentage = 75;
    }

    function getMinimumDeposit(StreamDenomination _denomination) public view returns (uint256) {
        return streamManager.getStreamById(uint64(_denomination)).securityBondValue;
    }

    function _initMemberBalance(Member storage _member) internal {
        uint64 streamsLength = streamManager.getStreamsLength();
        _member.balance.available = 0;
        for (uint256 i = 0; i < streamsLength; i++) {
            _member.balance.staked.push();
            _member.balance.applications.push(ApplicationData({requestedRole: Role.NONE, preStaked: 0}));
        }
    }

    function _getMemberTakePubKey(address _address) internal view returns (bytes32) {
        bytes32[] memory pubKeys = _getMember(_address).publicKeys;
        return pubKeys[uint8(PublicKeyIndex.TAKE)];
    }

    function _getOrRegisterMember(address _address, PublicKeyRegistration[] calldata _publicKeys)
        internal
        returns (Member storage)
    {
        Member storage member = members[_address];
        // Check if the member is already registered
        if (member.publicKeys.length == 0) {
            member = _registerMember(_address, _publicKeys);
        } else {
            // Check if the public keys are the same as the stored member's public keys
            for (uint8 i = 0; i < PUBLIC_KEYS_INDEX_LENGTH; i++) {
                if (member.publicKeys[i] != _publicKeys[i].publicKeyX) {
                    revert PublicKeyMismatch(i, member.publicKeys[i], _publicKeys[i].publicKeyX);
                }
            }
        }
        return member;
    }

    function _isMemberBanned(address _memberAddress, StreamDenomination _denomination) internal returns (bool) {
        // The member might not be registered yet, so we access the mapping directly
        Member storage member = members[_memberAddress];
        if (member.bannedTimestamp[_denomination] == 0) {
            return false; // Not banned
        }
        // Check if the ban is still active
        if (block.timestamp > member.bannedTimestamp[_denomination] + bannedMemberTimeout) {
            // Ban expired, remove the ban timestamp
            member.bannedTimestamp[_denomination] = 0;
            return false;
        }
        return true; // Still banned
    }

    function applyToStream(StreamDenomination _denomination, Role _role, PublicKeyRegistration[] calldata _publicKeys)
        external
        payable
    {
        // Check if the member is banned for the stream
        if (_isMemberBanned(msg.sender, _denomination) == true) {
            uint256 bannedAt = _getMember(msg.sender).bannedTimestamp[_denomination];
            revert MemberIsBannedForStream(msg.sender, _denomination, bannedAt, bannedAt + bannedMemberTimeout);
        }

        if (_role == Role.NONE) {
            revert RequestedNoneRoleForStream(_denomination);
        }

        // If the public keys length is not the same as the enum length revert
        uint256 publicKeysLength = _publicKeys.length;
        if (publicKeysLength != PUBLIC_KEYS_INDEX_LENGTH) {
            revert InvalidPublicKeysLength(publicKeysLength, PUBLIC_KEYS_INDEX_LENGTH);
        }

        Member storage member = _getOrRegisterMember(msg.sender, _publicKeys);

        if (member.balance.applications[uint8(_denomination)].requestedRole != Role.NONE) {
            revert MemberAlreadyRegisteredForStream(
                msg.sender, _denomination, _role, member.balance.applications[uint8(_denomination)].requestedRole
            );
        }
        uint256 minDeposit = getMinimumDeposit(_denomination);
        if (msg.value < minDeposit) {
            revert DespositBondTooLow(msg.value, minDeposit);
        }

        _registerCandidateToStream(msg.sender, _denomination, _role, msg.value);
        emit NewSecurityBondDeposit(msg.sender, _denomination, _role, msg.value);

        _createCommitteeAfterApplyToStream(_denomination);
    }

    // NOTE: This function intends to keep many different structures in sync, be careful when modifying it
    function _registerCandidateToStream(
        address _memberAddress,
        StreamDenomination _denomination,
        Role _role,
        uint256 _amount
    ) internal {
        Member storage member = _getMember(_memberAddress);

        member.balance.applications[uint8(_denomination)].preStaked = _amount;
        member.balance.applications[uint8(_denomination)].requestedRole = _role;

        committeesCandidates[_denomination][_role].push(_memberAddress);
    }

    function unsubscribeFromStream(StreamDenomination _denomination) external {
        if (_isInPendingCommittee(msg.sender, uint64(_denomination))) {
            revert MemberIsInPendingCommittee(msg.sender, _denomination);
        }

        _unsubscribeFromStream(msg.sender, _denomination);
        emit MemberUnsubscribedFromStream(msg.sender, _denomination);
    }

    function _isInPendingCommittee(address _memberAddress, uint64 _streamId) internal view returns (bool) {
        PendingCommittee storage pendingCommittee = pendingCommittees[_streamId];
        if (pendingCommittee.createdAt == 0) {
            return false; // No pending committee
        }
        return pendingCommittee.data[_memberAddress].inCommittee;
    }

    function _unsubscribeFromStream(address _memberAddress, StreamDenomination _denomination) internal {
        Member storage member = _getMember(_memberAddress);
        Role role = member.balance.applications[uint8(_denomination)].requestedRole;

        if (role == Role.NONE) {
            revert MemberIsNotCandidateForStream(_memberAddress, _denomination);
        }
        _movePreStakedToAvailable(member, _memberAddress, _denomination);
        _removeFromCandidates(_memberAddress, _denomination, role);
    }

    function _movePreStakedToAvailable(Member storage _member, address _memberAddress, StreamDenomination _denomination)
        internal
    {
        ApplicationData memory originalData = _member.balance.applications[uint8(_denomination)];
        _member.balance.applications[uint8(_denomination)] = ApplicationData({requestedRole: Role.NONE, preStaked: 0});

        _member.balance.available += originalData.preStaked;
        emit NewAvailableBalance(_memberAddress, _member.balance.available, originalData.preStaked);
    }

    function _movePreStakedToStaked(address _memberAddress, StreamDenomination _denomination, uint64 _packetNumber)
        internal
        returns (Role)
    {
        Member storage member = _getMember(_memberAddress);

        ApplicationData memory originalData = member.balance.applications[uint8(_denomination)];
        member.balance.applications[uint8(_denomination)] = ApplicationData({requestedRole: Role.NONE, preStaked: 0});

        // Save the pre-staked amount to the staked balance
        member.balance.staked[uint8(_denomination)][_packetNumber] = originalData.preStaked;
        return originalData.requestedRole;
    }

    function _removeCandidatesAndUpdateBalance(
        CommitteeMember[] memory _members,
        StreamDenomination _denomination,
        uint64 _packetNumber
    ) internal {
        for (uint256 i = 0; i < _members.length; i++) {
            Role role = _movePreStakedToStaked(_members[i].memberAddress, _denomination, _packetNumber);
            _removeFromCandidates(_members[i].memberAddress, _denomination, role);
        }
    }

    function _removeFromCandidates(address _memberAddress, StreamDenomination _stream, Role _role) internal {
        address[] storage candidates = committeesCandidates[_stream][_role];
        uint256 length = candidates.length;

        // NOTE: This effectively brings the last candidate forward in the list by replacing the removed member
        for (uint256 i = 0; i < length; i++) {
            if (candidates[i] == _memberAddress) {
                candidates[i] = candidates[length - 1];
                candidates.pop();
                break;
            }
        }
    }

    function withdrawAvailableBalance() external {
        Member storage member = _getMember(msg.sender);
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

    function _registerMember(address _memberAddress, PublicKeyRegistration[] calldata _publicKeys)
        internal
        returns (Member storage)
    {
        // Check if the public keys and the signatures associated are valid
        _validatePublicKeys(_publicKeys);

        Member storage member = members[_memberAddress]; // Get reference

        // Initialize Member public keys
        for (uint8 i = 0; i < PUBLIC_KEYS_INDEX_LENGTH; i++) {
            member.publicKeys.push(_publicKeys[i].publicKeyX);
        }

        _initMemberBalance(member);

        emit NewMember(member.publicKeys);
        return member;
    }

    function _registerCommittee(uint256 _committeeId, Committee storage _committee) internal {
        committeesByKey[_committeeId] = _committee;
        emit NewCommittee(_committeeId, _committee);
    }

    function getCommittee(uint256 _committeeId) public view returns (Committee memory) {
        Committee memory committee = committeesByKey[_committeeId];
        if (committee.members.length == 0) {
            revert CommitteeNotFound(_committeeId);
        }
        return committee;
    }

    function getCommitteeMembers(uint256 _committeeId) external view returns (CommitteeMember[] memory) {
        return getCommittee(_committeeId).members;
    }

    function getMemberTakePubKey(address _address) external view returns (bytes32) {
        return _getMemberTakePubKey(_address);
    }

    function getMemberPublicKeys(address _address) external view returns (bytes32[] memory publicKeys) {
        Member storage member = _getMember(_address);
        publicKeys = new bytes32[](PUBLIC_KEYS_INDEX_LENGTH);
        for (uint8 i = 0; i < PUBLIC_KEYS_INDEX_LENGTH; i++) {
            publicKeys[i] = member.publicKeys[i];
        }
        return publicKeys;
    }

    function _getMemberApplicationData(address _address, StreamDenomination _denomination)
        internal
        view
        returns (ApplicationData memory applicationData)
    {
        applicationData = _getMember(_address).balance.applications[uint8(_denomination)];
    }

    function getMemberRequestedRole(address _memberAddress, StreamDenomination _denomination)
        external
        view
        returns (Role)
    {
        return _getMemberApplicationData(_memberAddress, _denomination).requestedRole;
    }

    function getMemberAvailableBalance(address _address) external view returns (uint256) {
        return _getMember(_address).balance.available;
    }

    function getMemberPreStakedBalance(address _memberAddress, StreamDenomination _denomination)
        external
        view
        returns (uint256)
    {
        return _getMemberApplicationData(_memberAddress, _denomination).preStaked;
    }

    function getMemberStakedBalance(address _address, StreamDenomination _denomination, uint64 _packetNumber)
        external
        view
        returns (uint256 amount)
    {
        return _getMember(_address).balance.staked[uint8(_denomination)][_packetNumber];
    }

    function _getMember(address _address) internal view returns (Member storage member) {
        member = members[_address];
        if (member.publicKeys.length == 0) {
            revert MemberNotRegistered(_address);
        }
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

        _slashPendingCommittee(_streamId);
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

            _slashPendingCommittee(_streamId);
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
            _slashPendingCommittee(_streamId);
            _deletePendingCommittee(_streamId);
            _createCommittee(_streamId);
        }

        return true;
    }

    function _createCommittee(uint64 _streamId) internal returns (PendingCommitteeStatus) {
        // NOTE: This method is called from the pegManager, so we should not revert.
        (CommitteeMember[] memory committeeMembers, PendingCommitteeStatus status) = _selectCommittee(_streamId);
        if (status != PendingCommitteeStatus.SUCCESS) {
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
            pendingCommittees[_streamId].committee.members.push(committeeMembers[i]);

            // Initialize committee users pending data
            pendingCommittees[_streamId].data[committeeMembers[i].memberAddress] =
                PendingCommitteeData({inCommittee: true, aggregatedKey: bytes32(0)});
        }
        emit NewPendingCommittee(_streamId, pendingCommittees[_streamId].committee);
        return PendingCommitteeStatus.SUCCESS;
    }

    function depositMemberInfoForCommittee(uint64 _streamId, bytes32 _aggregatedKey) external {
        PendingCommittee storage pendingCommittee = pendingCommittees[_streamId];
        if (pendingCommittee.createdAt == 0) {
            revert CommitteeIsNotPending(_streamId);
        }

        if (_aggregatedKey == bytes32(0)) {
            revert InvalidAgregatedKey();
        }

        if (!pendingCommittee.data[msg.sender].inCommittee) {
            revert MemberNotInCommittee(_streamId, msg.sender);
        }

        if (pendingCommittee.data[msg.sender].aggregatedKey != bytes32(0)) {
            revert MemberInfoAlreadyDeposited(msg.sender);
        }

        pendingCommittee.data[msg.sender].aggregatedKey = _aggregatedKey;

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
        emit MemberInfoDeposited(_streamId, msg.sender, _aggregatedKey);
        if (pendingCommittee.missingData != 0) {
            // Committee is not completed yet
            return;
        }

        // Create unique committee id associated to the streamId and packetNumber.
        uint64 packetNumber = streamManager.getPacketsLength(_streamId);
        uint256 committeeId = uint256(keccak256(abi.encode(_streamId, packetNumber)));
        _removeCandidatesAndUpdateBalance(
            pendingCommittee.committee.members, StreamDenomination(_streamId), packetNumber
        );
        _registerCommittee(committeeId, pendingCommittee.committee);
        streamManager.createNewPacket(_streamId, committeeId, pendingCommittee.committee.aggregatedKey);
        _deletePendingCommittee(_streamId);
    }

    function _slashPendingCommittee(uint64 _streamId) internal {
        CommitteeMember[] memory committeeMembers = pendingCommittees[_streamId].committee.members;
        uint256 honestMembersCount = 0;
        address[] memory honestMembers = new address[](committeeMembers.length);
        uint256 rewardCollected = 0;

        for (uint256 i = 0; i < committeeMembers.length; i++) {
            PendingCommitteeData storage data = pendingCommittees[_streamId].data[committeeMembers[i].memberAddress];
            if (data.aggregatedKey == bytes32(0)) {
                rewardCollected +=
                    _slashDishonestMember(committeeMembers[i].memberAddress, StreamDenomination(_streamId));
            } else {
                honestMembers[honestMembersCount++] = committeeMembers[i].memberAddress;
            }
        }

        uint256 rewardPerMember = (rewardCollected * rewardPercentage) / 100;
        for (uint256 i = 0; i < honestMembersCount; i++) {
            Member storage member = _getMember(honestMembers[i]);
            // Add the reward to the available balance of the honest member
            member.balance.available += rewardPerMember;
            emit NewAvailableBalance(honestMembers[i], member.balance.available, rewardPerMember);
        }

        contractAvailableBalance += rewardCollected - (rewardPerMember * honestMembersCount);
    }

    function _slashDishonestMember(address _memberAddress, StreamDenomination _denomination)
        internal
        returns (uint256 slashedAmount)
    {
        Member storage member = _getMember(_memberAddress);
        uint256 preStaked = member.balance.applications[uint8(_denomination)].preStaked;

        slashedAmount = (preStaked * slashingPercentage) / 100;
        member.balance.applications[uint8(_denomination)].preStaked -= slashedAmount;

        _unsubscribeFromStream(_memberAddress, _denomination);

        member.bannedTimestamp[_denomination] = block.timestamp;
        emit MemberSlashed(_memberAddress, _denomination, slashedAmount);
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
        CommitteeMember[] storage committeeMembers = pendingCommittees[_streamId].committee.members;
        for (uint256 i = 0; i < committeeMembers.length; i++) {
            delete pendingCommittees[_streamId].data[committeeMembers[i].memberAddress];
        }
        //slither-disable-next-line mapping-deletion
        delete pendingCommittees[_streamId];
    }

    function getCommitteeCandidates(StreamDenomination _denomination, Role _role)
        external
        view
        returns (address[] memory)
    {
        return committeesCandidates[_denomination][_role];
    }

    /**
     * @notice Randomly selects members to form a new committee for a given stream
     * @dev Pseudo-randomly select at least minCommitteeWatchtowers watchtowers and minCommitteeOperators operators.
     * - reverts with notEnoughWatchtowers if there are fewer than minCommitteeWatchtowers watchtower candidates
     * - reverts with notEnoughOperators if there are fewer than minCommitteeOperators operator candidates
     *
     * @param _streamId The ID of the stream to select committee members for (0-4)
     * @return An array of minCommitteeMembers CommitteeMembers containing the selected members.
     *
     */
    function _selectCommittee(uint64 _streamId) internal returns (CommitteeMember[] memory, PendingCommitteeStatus) {
        // Get the stream denomination for the streamId
        StreamDenomination denomination = StreamDenomination(_streamId);

        // Get candidates per role.
        address[] memory watchtowers = committeesCandidates[denomination][Role.WATCHTOWER];
        address[] memory operators = committeesCandidates[denomination][Role.OPERATOR];
        uint256 watchtowersLength = watchtowers.length;
        uint256 operatorsLength = operators.length;

        // Ensure we have enough candidates
        if (watchtowersLength < minCommitteeWatchtowers) {
            emit MissingWatchtowers(denomination, minCommitteeWatchtowers, minCommitteeWatchtowers - watchtowersLength);
            return (new CommitteeMember[](0), PendingCommitteeStatus.NOT_ENOUGH_WATCHTOWERS);
        }

        if (operatorsLength < minCommitteeOperators) {
            emit MissingOperators(denomination, minCommitteeOperators, minCommitteeOperators - operatorsLength);
            return (new CommitteeMember[](0), PendingCommitteeStatus.NOT_ENOUGH_OPERATORS);
        }

        // Check if we have enough total members for the committee
        uint256 totalAvailableMembers = operatorsLength + watchtowersLength;
        if (totalAvailableMembers < minCommitteeMembers) {
            emit MissingMembers(denomination, minCommitteeMembers, minCommitteeMembers - totalAvailableMembers);
            return (new CommitteeMember[](0), PendingCommitteeStatus.NOT_ENOUGH_MEMBERS);
        }

        // Amount of each members per role in the committee
        // NOTE: Here assumme that minCommitteeMembers > minCommitteeWatchtowers + minCommitteeOperators
        uint256 operatorsCommitteeAmount = (minCommitteeMembers - minCommitteeWatchtowers > operatorsLength)
            ? operatorsLength
            : minCommitteeMembers - minCommitteeWatchtowers;
        uint256 watchtowerCommitteeAmount = minCommitteeMembers - operatorsCommitteeAmount;
        uint256 committeeMembersCounter = 0;

        // Create the final committee with minCommitteeMembers members
        CommitteeMember[] memory selectedMembers = new CommitteeMember[](minCommitteeMembers);

        // True randomness is not required here. We only need enough unpredictability to ensure
        // different committee members get selected across multiple runs.
        // We use Fisher-Yates shuffle because it guarantees each index is selected exactly once.
        // This way we avoid index collisions and infinite loops.

        // Select random operators
        for (uint256 length = operatorsLength; length > operatorsLength - operatorsCommitteeAmount; length--) {
            // slither-disable-next-line weak-prng
            uint256 randomPos = uint256(keccak256(abi.encode(block.timestamp, length))) % length;

            selectedMembers[committeeMembersCounter++] =
                CommitteeMember({memberAddress: operators[randomPos], role: Role.OPERATOR});

            // Just move last position to replace random position. There is no need to swap values now.
            operators[randomPos] = operators[length - 1];
        }

        // Select random watchtowers
        for (uint256 length = watchtowersLength; length > watchtowersLength - watchtowerCommitteeAmount; length--) {
            // slither-disable-next-line weak-prng
            uint256 randomPos = uint256(keccak256(abi.encode(block.timestamp, length))) % length;

            selectedMembers[committeeMembersCounter++] =
                CommitteeMember({memberAddress: watchtowers[randomPos], role: Role.WATCHTOWER});

            // Just move last position to replace random position. There is no need to swap values now.
            watchtowers[randomPos] = watchtowers[length - 1];
        }

        return (selectedMembers, PendingCommitteeStatus.SUCCESS);
    }

    function setStreamManager(IStreamManager _streamManager) external onlyOwner {
        if (address(_streamManager) == address(0)) {
            revert InvalidZeroAddress();
        }
        streamManager = _streamManager;
        emit StreamManagerUpdated(address(_streamManager));
    }

    function setPegManager(IPegManager _pegManager) external onlyOwner {
        if (address(_pegManager) == address(0)) {
            revert InvalidZeroAddress();
        }
        pegManager = _pegManager;
        emit PegManagerUpdated(address(_pegManager));
    }

    function setPendingCommitteeTimeout(uint256 _timeout) external onlyOwner {
        if (_timeout == 0) {
            revert InvalidZeroValue();
        }
        pendingCommitteeTimeout = _timeout;
        emit PendingCommitteeTimeoutUpdated(_timeout);
    }

    function setBannedMemberTimeout(uint256 _timeout) external onlyOwner {
        if (_timeout == 0) {
            revert InvalidZeroValue();
        }
        bannedMemberTimeout = _timeout;
        emit BannedMemberTimeoutUpdated(_timeout);
    }

    function setCommitteeMinWatchtowers(uint256 _minWatchtowers) external onlyOwner {
        if (_minWatchtowers == 0) {
            revert InvalidZeroValue();
        }
        minCommitteeWatchtowers = _minWatchtowers;
        emit CommitteeMinWatchtowersUpdated(_minWatchtowers);
    }

    function setCommitteeMinOperators(uint256 _minOperators) external onlyOwner {
        if (_minOperators == 0) {
            revert InvalidZeroValue();
        }
        minCommitteeOperators = _minOperators;
        emit CommitteeMinOperatorsUpdated(_minOperators);
    }

    function setCommitteeMinMembers(uint256 _minMembers) external onlyOwner {
        if (_minMembers == 0) {
            revert InvalidZeroValue();
        }
        if (_minMembers < minCommitteeWatchtowers + minCommitteeOperators) {
            revert InvalidMinMembers(_minMembers, minCommitteeWatchtowers, minCommitteeOperators);
        }
        minCommitteeMembers = _minMembers;
        emit CommitteeMinMembersUpdated(_minMembers);
    }

    function setSlashingPercentage(uint256 _percentage) external onlyOwner {
        if (_percentage > 100) {
            revert InvalidPercentage(_percentage);
        }
        if (_percentage == 0) {
            revert InvalidZeroValue();
        }
        slashingPercentage = _percentage;
        emit SlashingPercentageUpdated(_percentage);
    }

    function setMembersRewardPercentage(uint256 _percentage) external onlyPegManager {
        if (_percentage > 100) {
            revert InvalidPercentage(_percentage);
        }
        if (_percentage == 0) {
            revert InvalidZeroValue();
        }
        rewardPercentage = _percentage;
        emit RewardingPercentageUpdated(_percentage);
    }

    /// ==== Modifiers ====
    modifier onlyPegManager() {
        if (address(pegManager) != msg.sender) {
            revert UnauthorizedAccount(msg.sender);
        }
        _;
    }
}
