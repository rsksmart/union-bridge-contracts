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
    ApplicationData,
    Balance
} from "./interfaces/ICommitteeRegistry.sol";
import {StreamDenomination, IStreamManager} from "./interfaces/IStreamManager.sol";
import {IPegManager} from "./interfaces/IPegManager.sol";
import {SignatureData} from "./interfaces/ISignatureManager.sol";

/// @title CommitteeRegistry
/// @notice Manages registration, application, and selection of committee members for the union bridge system
/// @dev Handles member registration, role assignment, committee formation, staking, and candidate management for all streams
contract CommitteeRegistry is ICommitteeRegistry, BaseProxy {
    /// @notice Mapping of member addresses to their member data
    mapping(address => Member) internal members;

    /// @notice Maximum number of members allowed per committee
    uint256 public constant MAX_MEMBERS_PER_COMMITTEE = 100;

    /// @notice Minimum number of watchtowers required for a committee
    uint256 public minCommitteeWatchtowers;
    /// @notice Minimum number of operators required for a committee
    uint256 public minCommitteeOperators;
    /// @notice Minimum number of members required for a committee
    uint256 public minCommitteeMembers;

    /// @notice Mapping of streamId to pending committee data
    mapping(uint64 streamId => PendingCommittee) internal pendingCommittees;
    /// @notice Mapping of committeeId to committee data
    mapping(uint256 committeeId => Committee) internal committeesById;
    /// @notice Mapping of streamId to flag indicating if a committee should be created
    mapping(uint64 streamId => bool createCommittee) public shouldCreateCommittee;

    /// @notice Stream manager contract for managing streams and packets
    IStreamManager streamManager;
    /// @notice Peg manager contract for peg-in/peg-out coordination
    IPegManager pegManager;

    /// @notice Timeout in seconds for pending committee formation
    uint256 public pendingCommitteeTimeout;

    /// @notice Mapping of stream denomination and role to list of candidate addresses
    mapping(StreamDenomination denomination => mapping(Role role => address[] membersAddress)) internal
        committeesCandidates;

    /// @notice Initializes the CommitteeRegistry contract
    /// @param _initialOwner The initial owner of the contract
    function initialize(address _initialOwner) public virtual initializer {
        __BaseProxy_init(_initialOwner);
        pendingCommitteeTimeout = 1 days; // Default timeout for pending committees
        for (uint64 i = 0; i <= uint64(StreamDenomination._10BTC); i++) {
            shouldCreateCommittee[i] = true;
        }
        minCommitteeWatchtowers = 3;
        minCommitteeOperators = 3;
        minCommitteeMembers = 10;
    }

    function _initMemberBalance(Member storage _member) internal {
        uint64 streamsLength = streamManager.getStreamsLength();
        _member.balance.available = 0;
        for (uint256 i = 0; i < streamsLength; i++) {
            _member.balance.staked.push();
            _member.balance.applications.push(ApplicationData({requestedRole: Role.NONE, preStaked: 0, reApply: true}));
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

    /// @notice Applies to participate in a stream with a specific role
    /// @dev Registers public keys and deposits required bond for the requested role
    /// @param _stream The stream denomination to apply for
    /// @param _role The role requested in the committee
    /// @param _publicKeys Array of public key registrations for TAKE, COVENANT, and COMMUNICATION
    function applyToStream(StreamDenomination _stream, Role _role, PublicKeyRegistration[] calldata _publicKeys)
        external
        payable
    {
        if (_role == Role.NONE) {
            revert RequestedNoneRoleForStream(_stream);
        }
        // If the public keys length is not the same as the enum length revert
        uint256 publicKeysLength = _publicKeys.length;
        if (publicKeysLength != PUBLIC_KEYS_INDEX_LENGTH) {
            revert InvalidPublicKeysLength(publicKeysLength, PUBLIC_KEYS_INDEX_LENGTH);
        }

        Member storage member = _getOrRegisterMember(msg.sender, _publicKeys);

        if (_role == Role.NONE) {
            revert RequestedNoneRoleForStream(_stream);
        }
        if (member.balance.applications[uint8(_stream)].requestedRole != Role.NONE) {
            revert MemberAlreadyRegisteredForStream(
                msg.sender, _stream, _role, member.balance.applications[uint8(_stream)].requestedRole
            );
        }
        uint256 minDeposit = streamManager.getMinimumDeposit(_stream, _role);
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
        Member storage member = _getMember(_memberAddress);

        member.balance.applications[uint8(_stream)].preStaked = _amount;
        member.balance.applications[uint8(_stream)].requestedRole = _role;

        committeesCandidates[_stream][_role].push(_memberAddress);
    }

    /// @notice Unsubscribes from a stream and sets the pre-staked balance as available
    /// @param _denomination The stream denomination to unsubscribe from
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
        _member.balance.applications[uint8(_denomination)] =
            ApplicationData({requestedRole: Role.NONE, preStaked: 0, reApply: true});

        _member.balance.available += originalData.preStaked;
        emit NewAvailableBalance(_memberAddress, _member.balance.available, originalData.preStaked);
    }

    function _movePreStakedToStaked(address _memberAddress, StreamDenomination _denomination, uint64 _packetNumber)
        internal
        returns (Role)
    {
        Member storage member = _getMember(_memberAddress);

        ApplicationData memory originalData = member.balance.applications[uint8(_denomination)];
        member.balance.applications[uint8(_denomination)] =
            ApplicationData({requestedRole: Role.NONE, preStaked: 0, reApply: originalData.reApply});

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

    /// @notice Withdraws available balance to the caller's address
    /// @dev Can only withdraw balance that is not pre-staked or staked
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
        committeesById[_committeeId] = _committee;
        emit NewCommittee(_committeeId, _committee);
    }

    /// @notice Gets a committee by its ID
    /// @param _committeeId The committee ID
    /// @return Committee The complete committee information
    function getCommittee(uint256 _committeeId) external view returns (Committee memory) {
        return _getCommittee(_committeeId);
    }

    function _getCommittee(uint256 _committeeId) internal view returns (Committee storage) {
        Committee storage committee = committeesById[_committeeId];
        if (committee.members.length == 0) {
            revert CommitteeNotFound(_committeeId);
        }
        return committee;
    }

    /// @notice Gets all members of a specific committee
    /// @param _committeeId The committee ID
    /// @return Array of committee members with their roles
    function getCommitteeMembers(uint256 _committeeId) external view returns (CommitteeMember[] memory) {
        return _getCommitteeMembers(_committeeId);
    }

    function _getCommitteeMembers(uint256 _committeeId) internal view returns (CommitteeMember[] memory) {
        return _getCommittee(_committeeId).members;
    }

    /// @notice Gets the TAKE public key for a specific member
    /// @param _address The member's address
    /// @return The TAKE public key (x-coordinate only)
    function getMemberTakePubKey(address _address) external view returns (bytes32) {
        return _getMemberTakePubKey(_address);
    }

    /// @notice Retrieves all public keys for a specific member
    /// @param _address The member's address
    /// @return publicKeys Array of public keys indexed by PublicKeyIndex
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
        returns (ApplicationData storage)
    {
        return _getMember(_address).balance.applications[uint8(_denomination)];
    }

    /// @notice Gets the requested role for a member in a specific stream
    /// @param _memberAddress The member's address
    /// @param _denomination The stream denomination
    /// @return The requested role for the member
    function getMemberRequestedRole(address _memberAddress, StreamDenomination _denomination)
        external
        view
        returns (Role)
    {
        return _getMemberApplicationData(_memberAddress, _denomination).requestedRole;
    }

    /// @notice Gets the available balance for a member
    /// @param _address The member's address
    /// @return The available balance that can be withdrawn
    function getMemberAvailableBalance(address _address) external view returns (uint256) {
        return _getMember(_address).balance.available;
    }

    /// @notice Gets the pre-staked balance for a member in a specific stream
    /// @param _memberAddress The member's address
    /// @param _denomination The stream denomination
    /// @return The pre-staked balance for the stream
    function getMemberPreStakedBalance(address _memberAddress, StreamDenomination _denomination)
        external
        view
        returns (uint256)
    {
        return _getMemberApplicationData(_memberAddress, _denomination).preStaked;
    }

    /// @notice Gets the staked balance for a member in a specific stream and packet
    /// @param _address The member's address
    /// @param _denomination The stream denomination
    /// @param _packetNumber The packet number
    /// @return amount The staked amount in the packet
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

        _slashCommittee();
        _deletePendingCommittee(_streamId);
        _createCommittee(_streamId);
    }

    /// @notice Triggers the creation of a new committee for a stream if the timeout has expired
    /// @dev This function is called when the slot usage threshold is reached
    /// @param _streamId The stream ID to create a new committee for
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

    /// @notice Allows a member to deposit information for committee formation
    /// @dev Called by members to provide their aggregated key for a pending committee
    /// @param _streamId The stream ID for the pending committee
    /// @param _aggregatedKey The aggregated public key provided by the member
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

    function _slashCommittee() internal {
        // TODO: slash the members. Sasasaaa.
    }

    /// @notice Returns the pending committee for the stream
    /// @dev This function will revert if  there is no pending committee or if it's expired
    /// @param _streamId The stream ID to get the pending committee for
    /// @return committee The pending committee
    /// @return createdAt The timestamp when the pending committee was created
    /// @return missingData The number of members that have not provided their data yet
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

    /// @notice Checks if there is a pending committee for the stream and if it's expired
    /// @param _streamId The stream ID to check for a pending committee
    /// @return True if the pending committee exists and is expired
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

    /// @notice Gets all candidates for a specific role in a stream
    /// @param _denomination The stream denomination
    /// @param _role The role to get candidates for
    /// @return Array of candidate addresses
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

    /// @notice Gets the next available operator address for take operations
    /// @dev Rotates through committee operators to distribute take responsibilities
    /// @dev Only operators who have deposited their signatures are eligible for take operations
    /// @param _committeeId The committee ID to get the operator from
    /// @param _signatureData Array of signature data for committee members
    /// @return The address of the next available operator for take operations
    /// @dev Reverts with TakeOperatorNotFound if no eligible operator is found
    function getOperatorTakeAddress(uint256 _committeeId, SignatureData[] memory _signatureData)
        external
        onlyPegManager
        returns (address)
    {
        Committee storage committee = _getCommittee(_committeeId);
        uint256 membersLength = committee.members.length;
        // This is the last operator that did the advancement of funds. Start from the next one.
        uint256 operatorTakeIndex = (committee.operatorTakeIndex + 1) % membersLength;

        for (uint256 i = 0; i < membersLength; i++) {
            if (
                committee.members[operatorTakeIndex].role == Role.OPERATOR
                    && _signatureData[operatorTakeIndex].signature != bytes32(0)
            ) {
                committee.operatorTakeIndex = operatorTakeIndex;
                return committee.members[operatorTakeIndex].memberAddress;
            }

            operatorTakeIndex = (operatorTakeIndex + 1) % membersLength;
        }

        revert TakeOperatorNotFound(_committeeId);
    }

    /// @notice Sets the Stream Manager contract address
    /// @dev Only callable by the contract owner
    /// @param _streamManager The address of the Stream Manager contract
    function setStreamManager(IStreamManager _streamManager) external onlyOwner {
        if (address(_streamManager) == address(0)) {
            revert InvalidZeroAddress();
        }
        streamManager = _streamManager;
        emit StreamManagerUpdated(address(_streamManager));
    }

    /// @notice Sets the Peg Manager contract address
    /// @dev Only callable by the contract owner
    /// @param _pegManager The address of the Peg Manager contract
    function setPegManager(IPegManager _pegManager) external onlyOwner {
        if (address(_pegManager) == address(0)) {
            revert InvalidZeroAddress();
        }
        pegManager = _pegManager;
        emit PegManagerUpdated(address(_pegManager));
    }

    /// @notice Sets the pending committee timeout
    /// @dev Only callable by the contract owner
    /// @param _timeout The timeout in seconds for the pending committee
    function setPendingCommitteeTimeout(uint256 _timeout) external onlyOwner {
        if (_timeout == 0) {
            revert InvalidZeroValue();
        }
        pendingCommitteeTimeout = _timeout;
        emit PendingCommitteeTimeoutUpdated(_timeout);
    }

    /// @notice Sets the minimum watchtowers required for a committee
    /// @dev Only callable by the contract owner
    /// @param _minWatchtowers The minimum watchtowers required for a committee
    function setCommitteeMinWatchtowers(uint256 _minWatchtowers) external onlyOwner {
        if (_minWatchtowers == 0) {
            revert InvalidZeroValue();
        }
        if (minCommitteeMembers < _minWatchtowers + minCommitteeOperators) {
            revert InvalidMinWatchtowers(minCommitteeMembers, _minWatchtowers, minCommitteeOperators);
        }
        minCommitteeWatchtowers = _minWatchtowers;
        emit CommitteeMinWatchtowersUpdated(_minWatchtowers);
    }

    /// @notice Sets the minimum operators required for a committee
    /// @dev Only callable by the contract owner
    /// @param _minOperators The minimum operators required for a committee
    function setCommitteeMinOperators(uint256 _minOperators) external onlyOwner {
        if (_minOperators == 0) {
            revert InvalidZeroValue();
        }
        if (minCommitteeMembers < minCommitteeWatchtowers + _minOperators) {
            revert InvalidMinOperators(minCommitteeMembers, minCommitteeWatchtowers, _minOperators);
        }
        minCommitteeOperators = _minOperators;
        emit CommitteeMinOperatorsUpdated(_minOperators);
    }

    /// @notice Sets the minimum members required for a committee
    /// @dev Only callable by the contract owner
    /// @param _minMembers The minimum number of members required for a committee
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

    /// @notice Releases committee members from a packet and handles their staked balance
    /// @dev Called by PegManager to release committee members after packet completion
    /// @dev Members with reApply=true will be re-added as candidates, others get their balance as available
    /// @param _streamId The stream ID for the committee
    /// @param _packetNumber The packet number where the committee was active
    function releaseCommittee(uint64 _streamId, uint64 _packetNumber) external onlyPegManager {
        uint256 committeeId = streamManager.getCommitteeId(_streamId, _packetNumber);
        CommitteeMember[] memory committeeMembers = _getCommitteeMembers(committeeId);

        for (uint256 i = 0; i < committeeMembers.length; i++) {
            Member storage member = _getMember(committeeMembers[i].memberAddress);
            ApplicationData storage application = member.balance.applications[uint8(_streamId)];

            if (application.reApply && application.requestedRole == Role.NONE) {
                // If the member has reApply set to true, we should move the staked amount to pre-staked
                // and set them as candidate again (except the case they are already a candidate which can happen in some edge cases)
                _reapplyToStream(
                    committeeMembers[i].memberAddress,
                    StreamDenomination(_streamId),
                    _packetNumber,
                    committeeMembers[i].role
                );
            } else {
                // If the member has reApply set to false, we should move the staked amount to available
                _moveStakedToAvailable(committeeMembers[i].memberAddress, StreamDenomination(_streamId), _packetNumber);
            }
        }
    }

    function _reapplyToStream(
        address _memberAddress,
        StreamDenomination _denomination,
        uint64 _packetNumber,
        Role _role
    ) internal {
        Balance storage balance = _getMember(_memberAddress).balance;
        ApplicationData storage application = balance.applications[uint8(_denomination)];

        if (application.preStaked != 0) {
            revert _inconsistentPreStakedBalanceAndRole(
                _memberAddress, _denomination, application.preStaked, application.requestedRole
            );
        }
        application.preStaked = balance.staked[uint8(_denomination)][_packetNumber];
        balance.staked[uint8(_denomination)][_packetNumber] = 0;
        application.requestedRole = _role;

        committeesCandidates[_denomination][_role].push(_memberAddress);

        emit MemberReApplied(_memberAddress, _denomination, _role, application.preStaked);
    }

    function _moveStakedToAvailable(address _memberAddress, StreamDenomination _denomination, uint64 _packetNumber)
        internal
    {
        Balance storage balance = _getMember(_memberAddress).balance;
        uint256 stakedAmount = balance.staked[uint8(_denomination)][_packetNumber];
        balance.available += stakedAmount;
        balance.staked[uint8(_denomination)][_packetNumber] = 0;

        emit NewAvailableBalance(_memberAddress, balance.available, stakedAmount);
    }

    /// @notice Sets the reapply flag for a member in a specific stream
    /// @dev Controls whether the member will automatically reapply after committee release
    /// @param _denomination The stream denomination to set the flag for
    /// @param _reApply True to automatically reapply, false to receive balance as available
    function setReApplyForStream(StreamDenomination _denomination, bool _reApply) external {
        ApplicationData storage applicationData = _getMemberApplicationData(msg.sender, _denomination);
        applicationData.reApply = _reApply;

        emit MemberReApplyUpdated(msg.sender, _denomination, _reApply);
    }

    /// @notice Gets the reapply flag for a member in a specific stream
    /// @param _denomination The stream denomination to check
    /// @return True if the member will automatically reapply, false otherwise
    function getReApplyForStream(StreamDenomination _denomination) external view returns (bool) {
        return _getMemberApplicationData(msg.sender, _denomination).reApply;
    }

    // ===================== Modifiers =====================
    /// @notice Modifier to restrict access to the PegManager contract
    /// @dev Reverts if the caller is not the PegManager
    modifier onlyPegManager() {
        if (address(pegManager) != msg.sender) {
            revert UnauthorizedAccount(msg.sender);
        }
        _;
    }
}
