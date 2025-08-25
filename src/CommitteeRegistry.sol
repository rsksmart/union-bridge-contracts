// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {BaseProxy} from "./BaseProxy.sol";
import {
    Role,
    Member,
    CommitteeMember,
    Committee,
    ICommitteeRegistry,
    PendingCommitteeStatus,
    PendingCommitteeData,
    ECDSAPublicKey,
    RSAPublicKey,
    MemberRegistrationKeys,
    MemberKeys,
    RSA_PUBLIC_KEY_CHUNKS,
    PublicKeyType,
    ApplicationData,
    Balance,
    CommunicationData,
    UTXO
} from "./interfaces/ICommitteeRegistry.sol";
import {StreamDenomination, IStreamManager} from "./interfaces/IStreamManager.sol";
import {IPegManager} from "./interfaces/IPegManager.sol";
import {SignatureData} from "./interfaces/ISignatureManager.sol";
import {Constants} from "./libraries/Constants.sol";
import {BytesHelper} from "./libraries/BytesHelper.sol";

/// @title CommitteeRegistry
/// @notice Manages registration, application, and selection of committee members for the union bridge system
/// @dev Handles member registration, role assignment, committee formation, staking, and candidate management for all streams
contract CommitteeRegistry is ICommitteeRegistry, BaseProxy {
    /// @notice Mapping of member addresses to their member data
    mapping(address => Member) internal members;

    /// @notice Minimum number of watchtowers required for a committee
    uint256 public minCommitteeWatchtowers;
    /// @notice Minimum number of operators required for a committee
    uint256 public minCommitteeOperators;
    /// @notice Minimum number of members required for a committee
    uint256 public committeeMemberCount;

    /// @notice Mapping of streamId to the committee id
    mapping(uint64 streamId => uint128) internal pendingCommittees;
    /// @notice Mapping of committeeId to committee data
    mapping(uint128 committeeId => Committee) internal committeesById;

    /// @notice Mapping of member addresses to their pending data
    mapping(uint128 committeeId => mapping(address memberAddress => PendingCommitteeData)) committeesData;

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
        committeeMemberCount = 10;
    }

    function _initMemberBalance(Member storage _member) internal {
        uint64 streamsLength = streamManager.getStreamsLength();
        _member.balance.available = 0;
        for (uint256 i = 0; i < streamsLength; i++) {
            _member.balance.staked.push();
            _member.balance.applications.push(
                ApplicationData({
                    requestedRole: Role.NONE,
                    preStaked: 0,
                    reApply: true,
                    fundingUTXO: UTXO({txid: bytes32(0), outputIndex: 0, amount: 0})
                })
            );
        }
    }

    function _getMemberTakePubKey(address _address) internal view returns (bytes32) {
        return _getMember(_address).publicKeys.takePubKey;
    }

    function _getMemberComPubKey(address _address) internal view returns (RSAPublicKey memory) {
        return _getMember(_address).publicKeys.communicationPubKey;
    }

    function _validateFundingUTXO(UTXO calldata _utxo) internal pure {
        if (_utxo.txid == bytes32(0)) {
            revert ZeroUTXOTxid(_utxo);
        }

        if (_utxo.amount == 0) {
            revert ZeroUTXOAmount(_utxo);
        }
        // Additional validation could be added here, such as:
        // - Checking outputIndex is reasonable (not max uint32)
    }

    function _getOrRegisterMember(address _address, MemberRegistrationKeys calldata _publicKeys)
        internal
        returns (Member storage)
    {
        Member storage member = members[_address];
        // Check if the member is already registered
        if (member.publicKeys.takePubKey == bytes32(0)) {
            member = _registerMember(_address, _publicKeys);
        } else {
            // Check if the public keys are the same as the stored member's public keys
            _validateMemberKeyMatch(member, _publicKeys);
        }
        return member;
    }

    /// @notice Applies to participate in a stream with a specific role
    /// @dev Registers public keys, deposits required bond, and provides funding UTXO for the requested role
    /// @param _stream The stream denomination to apply for
    /// @param _role The role requested in the committee
    /// @param _publicKeys Member registration public keys
    /// @param _fundingUTXO The Bitcoin UTXO that will be used for the member funding
    function applyToStream(
        StreamDenomination _stream,
        Role _role,
        MemberRegistrationKeys calldata _publicKeys,
        UTXO calldata _fundingUTXO
    ) external payable {
        Member storage member = _getOrRegisterMember(msg.sender, _publicKeys);

        if (_role == Role.NONE) {
            revert RequestedNoneRoleForStream(_stream);
        }
        if (_role == Role.OPERATOR) {
            _validateFundingUTXO(_fundingUTXO);
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

        _registerCandidateToStream(msg.sender, _stream, _role, msg.value, _fundingUTXO);
        emit NewSecurityBondDeposit(msg.sender, _stream, _role, msg.value);

        _createCommitteeAfterApplyToStream(_stream);
    }

    function _committeesCandidatesHasSpace(StreamDenomination _denomination, Role _role) internal view returns (bool) {
        return committeesCandidates[_denomination][_role].length < Constants.MAX_CANDIDATES_SIZE_PER_ROLE;
    }

    // NOTE: This function intends to keep many different structures in sync, be careful when modifying it
    function _registerCandidateToStream(
        address _memberAddress,
        StreamDenomination _denomination,
        Role _role,
        uint256 _amount,
        UTXO calldata _fundingUTXO
    ) internal {
        if (!_committeesCandidatesHasSpace(_denomination, _role)) {
            revert TooManyCandidatesForStream(_denomination, _role);
        }

        Member storage member = _getMember(_memberAddress);

        member.balance.applications[uint8(_denomination)].preStaked = _amount;
        member.balance.applications[uint8(_denomination)].requestedRole = _role;
        member.balance.applications[uint8(_denomination)].fundingUTXO = _fundingUTXO;

        committeesCandidates[_denomination][_role].push(_memberAddress);
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
        uint128 committeeId = pendingCommittees[_streamId];
        // NOTE: Slither flags this as dangerous-strict-equalities, but this is a false positive.
        if (committeeId == 0) {
            return false; // No pending committee
        }
        return committeesData[committeeId][_memberAddress].inCommittee;
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
        _member.balance.applications[uint8(_denomination)] = ApplicationData({
            requestedRole: Role.NONE,
            preStaked: 0,
            reApply: true,
            fundingUTXO: UTXO({txid: bytes32(0), outputIndex: 0, amount: 0})
        });

        _member.balance.available += originalData.preStaked;
        emit NewAvailableBalance(_memberAddress, _member.balance.available, originalData.preStaked);
    }

    function _movePreStakedToStaked(address _memberAddress, StreamDenomination _denomination, uint64 _packetNumber)
        internal
        returns (Role)
    {
        Member storage member = _getMember(_memberAddress);

        ApplicationData memory originalData = member.balance.applications[uint8(_denomination)];
        member.balance.applications[uint8(_denomination)] = ApplicationData({
            requestedRole: Role.NONE,
            preStaked: 0,
            reApply: originalData.reApply,
            fundingUTXO: UTXO({txid: bytes32(0), outputIndex: 0, amount: 0})
        });

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

    function _isRSAKeyEmpty(bytes32[RSA_PUBLIC_KEY_CHUNKS] memory _rsaPublicKey) internal pure returns (bool) {
        for (uint256 i = 0; i < RSA_PUBLIC_KEY_CHUNKS; i++) {
            if (_rsaPublicKey[i] != bytes32(0)) {
                return false;
            }
        }
        return true;
    }

    function _getRSAKeyHash(bytes32[RSA_PUBLIC_KEY_CHUNKS] memory _rsaPublicKey) internal pure returns (bytes32) {
        return keccak256(abi.encode(_rsaPublicKey));
    }

    function _getAddressFromPublicKey(bytes memory _uncompressedPublicKey) internal pure returns (address) {
        return address(uint160(uint256(keccak256(_uncompressedPublicKey))));
    }

    function _validatePublicKeys(MemberRegistrationKeys calldata _publicKeys) internal pure {
        _validateECDSAKey(_publicKeys.takeKey, PublicKeyType.TAKE);

        // Placeholder for COVENANT key validation

        _validateRSAKey(_publicKeys.communicationKey, PublicKeyType.COMMUNICATION);
    }

    function _validateECDSAKey(ECDSAPublicKey calldata _key, PublicKeyType _type) internal pure {
        // Check if the public keys is not 0
        if (_key.publicKeyX == bytes32(0) || _key.publicKeyY == bytes32(0)) {
            revert InvalidZeroEDCSAPublicKey(_type, _key.publicKeyX, _key.publicKeyY);
        }

        // Validate signature is not zero
        if (_key.v == 0 || _key.r == bytes32(0) || _key.s == bytes32(0)) {
            revert InvalidZeroEDCSASignature(_type, _key);
        }

        // Use the uncompressed public key as the message
        bytes memory uncompressedPublicKey = abi.encode(_key.publicKeyX, _key.publicKeyY);
        bytes32 messageHash = keccak256(uncompressedPublicKey);

        // Validate the signature for the message is valid
        // * The `ecrecover` EVM precompile allows for malleable (non-unique) signatures:
        // * this function rejects them by requiring the `s` value to be in the lower
        // * half order, and the `v` value to be either 27 or 28.
        address recoveredSignerAddress = ECDSA.recover(messageHash, _key.v, _key.r, _key.s);

        // Get the expectedsigner address from the uncompressed public key
        address expectedSignerAddress = _getAddressFromPublicKey(uncompressedPublicKey);

        // Validate the recovered signer address is the same as the expected signer address
        if (recoveredSignerAddress != expectedSignerAddress) {
            revert InvalidEDCSASignature(_type, _key, recoveredSignerAddress, expectedSignerAddress);
        }
    }

    function _validateRSAKey(RSAPublicKey calldata _key, PublicKeyType _type) internal pure {
        // Check if RSA key is empty
        if (_isRSAKeyEmpty(_key.rsaPublicKey)) {
            revert InvalidZeroRSAPublicKey(_type);
        }
    }

    function _validateMemberKeyMatch(Member storage _member, MemberRegistrationKeys calldata _publicKeys)
        internal
        view
    {
        // TAKE key
        if (_member.publicKeys.takePubKey != _publicKeys.takeKey.publicKeyX) {
            revert PublicKeyMismatch(PublicKeyType.TAKE, _member.publicKeys.takePubKey, _publicKeys.takeKey.publicKeyX);
        }
        // COVENANT key
        if (_member.publicKeys.covenantPubKey != _publicKeys.covenantKey.publicKeyX) {
            revert PublicKeyMismatch(
                PublicKeyType.COVENANT, _member.publicKeys.covenantPubKey, _publicKeys.covenantKey.publicKeyX
            );
        }
        // COMMUNICATION key - compare RSA hashes
        bytes32 storedComKeyHash = _getRSAKeyHash(_member.publicKeys.communicationPubKey.rsaPublicKey);
        bytes32 newComKeyHash = _getRSAKeyHash(_publicKeys.communicationKey.rsaPublicKey);
        if (storedComKeyHash != newComKeyHash) {
            revert PublicKeyMismatch(PublicKeyType.COMMUNICATION, storedComKeyHash, newComKeyHash);
        }
    }

    function _registerMember(address _memberAddress, MemberRegistrationKeys calldata _publicKeys)
        internal
        returns (Member storage)
    {
        // Check if the public keys and the signatures associated are valid
        _validatePublicKeys(_publicKeys);

        Member storage member = members[_memberAddress]; // Get reference

        // Initialize Member public keys from the struct
        member.publicKeys.takePubKey = _publicKeys.takeKey.publicKeyX;
        member.publicKeys.covenantPubKey = _publicKeys.covenantKey.publicKeyX;
        member.publicKeys.communicationPubKey = _publicKeys.communicationKey;

        _initMemberBalance(member);

        // Emit event with the stored public keys
        emit NewMember(_memberAddress, member.publicKeys);
        return member;
    }

    /// @notice Gets a committee by its ID
    /// @param _committeeId The committee ID
    /// @return Committee The complete committee information
    function getCommittee(uint128 _committeeId) external view returns (Committee memory) {
        return _getCommittee(_committeeId);
    }

    function _getCommittee(uint128 _committeeId) internal view returns (Committee storage) {
        Committee storage committee = committeesById[_committeeId];
        if (committee.members.length == 0) {
            revert CommitteeNotFound(_committeeId);
        }
        return committee;
    }

    /// @notice Gets all members of a specific committee
    /// @param _committeeId The committee ID
    /// @return Array of committee members with their roles
    function getCommitteeMembers(uint128 _committeeId) external view returns (CommitteeMember[] memory) {
        return _getCommitteeMembers(_committeeId);
    }

    function _getCommitteeMembers(uint128 _committeeId) internal view returns (CommitteeMember[] memory) {
        return _getCommittee(_committeeId).members;
    }

    /// @notice Gets the TAKE public key for a specific member
    /// @param _address The member's address
    /// @return The TAKE public key (x-coordinate only)
    function getMemberTakePubKey(address _address) external view returns (bytes32) {
        return _getMemberTakePubKey(_address);
    }

    /// @notice Gets the COMMUNICATION public key for a specific member
    /// @param _address The member's address
    /// @return The RSA COMMUNICATION public key
    function getMemberComPubKey(address _address) external view returns (RSAPublicKey memory) {
        return _getMemberComPubKey(_address);
    }

    /// @notice Retrieves all public keys for a specific member
    /// @param _address The member's address
    /// @return publicKeys Member public keys structure
    function getMemberPublicKeys(address _address) external view returns (MemberKeys memory publicKeys) {
        return _getMember(_address).publicKeys;
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

    /// @notice Gets the funding UTXO for a member in a specific stream
    /// @param _streamId The stream ID
    /// @param _memberAddress The member's address
    /// @return The funding UTXO for the member's application to the stream
    function getMemberFundingUTXO(uint64 _streamId, address _memberAddress) external view returns (UTXO memory) {
        return _getMemberApplicationData(_memberAddress, StreamDenomination(_streamId)).fundingUTXO;
    }

    function _getMember(address _address) internal view returns (Member storage member) {
        member = members[_address];
        if (member.publicKeys.takePubKey == bytes32(0)) {
            revert MemberNotRegistered(_address);
        }
    }

    function restartPendingCommittee(uint64 _streamId) external {
        uint256 createdAt = _getPendingCommittee(_streamId).createdAt;

        // slither-disable-next-line timestamp
        if (block.timestamp < createdAt + pendingCommitteeTimeout) {
            // This is called from the pegManager, so we should not revert.
            revert PendingCommitteeNotExpired(_streamId, createdAt, createdAt + pendingCommitteeTimeout);
        }

        _deletePendingCommittee(_streamId);
        _createCommittee(_streamId);
    }

    /// @notice Triggers the creation of a new committee for a stream if the timeout has expired
    /// @dev This function is called when the slot usage threshold is reached
    /// @param _streamId The stream ID to create a new committee for
    function createCommittee(uint64 _streamId) external onlyPegManager {
        // NOTE: This method is called from the pegManager, so we should not revert.

        uint256 createdAt = committeesById[pendingCommittees[_streamId]].createdAt;

        if (createdAt != 0) {
            // slither-disable-next-line timestamp
            if (block.timestamp < createdAt + pendingCommitteeTimeout) {
                return;
            }

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
        uint256 createdAt = committeesById[pendingCommittees[_streamId]].createdAt;
        if (createdAt == 0) {
            return false;
        }

        // slither-disable-next-line timestamp
        if (block.timestamp >= createdAt + pendingCommitteeTimeout) {
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
        uint128 committeeId = uint128(uint256(keccak256(abi.encode(_streamId, block.number))));
        pendingCommittees[_streamId] = committeeId;

        Committee storage committee = committeesById[committeeId];
        committee.createdAt = block.timestamp;
        committee.missingData = uint16(committeeMembers.length);
        committee.missingCommunicationData = uint16(committeeMembers.length);
        committee.aggregatedKey = bytes32(0);
        committee.streamId = _streamId;
        committee.isPending = true;

        // Initialize the committee members here.
        // No need to initialize aggregatedKey, since it will be set by the members.
        for (uint256 i = 0; i < committeeMembers.length; i++) {
            // Copy committee members from memory to storage
            committee.members.push(committeeMembers[i]);

            committee.fundingUTXOs.push(
                _getMemberApplicationData(committeeMembers[i].memberAddress, StreamDenomination(_streamId)).fundingUTXO
            );

            // Initialize committee users pending data
            committeesData[committeeId][committeeMembers[i].memberAddress].inCommittee = true;
        }
        emit NewPendingCommittee(committeeId, committee);
        return PendingCommitteeStatus.SUCCESS;
    }

    function _isInCommitteeOrRevert(uint128 _committeeId, address _memberAddress) internal view {
        if (!committeesData[_committeeId][_memberAddress].inCommittee) {
            revert MemberNotInCommittee(_committeeId, _memberAddress);
        }
    }

    /// @notice Allows a member to deposit information for committee formation
    /// @dev Called by members to provide their aggregated key for a pending committee
    /// @param _committeeId The ID of the pending committee
    /// @param _aggregatedKey The aggregated public key provided by the member
    function depositAggregatedKey(uint128 _committeeId, bytes32 _aggregatedKey) external {
        Committee storage pendingCommittee = _getPendingCommitteeById(_committeeId);

        if (_aggregatedKey == bytes32(0)) {
            revert InvalidAggregatedKey();
        }

        _isInCommitteeOrRevert(_committeeId, msg.sender);

        if (committeesData[_committeeId][msg.sender].aggregatedKey != bytes32(0)) {
            revert MemberInfoAlreadyDeposited(_committeeId, msg.sender);
        }

        committeesData[_committeeId][msg.sender].aggregatedKey = _aggregatedKey;

        if (pendingCommittee.aggregatedKey == bytes32(0)) {
            // Save the aggregated key for the committee
            pendingCommittee.aggregatedKey = _aggregatedKey;
        } else {
            if (pendingCommittee.aggregatedKey != _aggregatedKey) {
                _deletePendingCommittee(pendingCommittee.streamId);
                _createCommittee(pendingCommittee.streamId); // Ignoring checks
                return;
            }
        }

        pendingCommittee.missingData--;
        emit MemberInfoDeposited(_committeeId, msg.sender, _aggregatedKey);
        if (pendingCommittee.missingData != 0) {
            // Committee is not completed yet
            return;
        }

        // Create unique committee id associated to the streamId and packetNumber.
        uint64 packetNumber = streamManager.getPacketsLength(pendingCommittee.streamId);
        bytes32 aggregatedKey = pendingCommittee.aggregatedKey;
        _removeCandidatesAndUpdateBalance(
            pendingCommittee.members, StreamDenomination(pendingCommittee.streamId), packetNumber
        );

        _deletePendingCommittee(pendingCommittee.streamId);
        emit NewCommittee(_committeeId, pendingCommittee);
        streamManager.createNewPacket(pendingCommittee.streamId, _committeeId, aggregatedKey);
    }

    function depositCommunicationData(uint128 _committeeId, CommunicationData[] memory _communicationData) external {
        Committee storage pendingCommittee = _getPendingCommitteeById(_committeeId);

        CommunicationData[] storage communicationDataStorage =
            committeesData[_committeeId][msg.sender].communicationData;
        CommitteeMember[] storage committeeMembers = pendingCommittee.members;

        _isInCommitteeOrRevert(_committeeId, msg.sender);

        if (communicationDataStorage.length != 0) {
            revert MemberAlreadyDepositedCommunicationData(_committeeId, msg.sender, communicationDataStorage.length);
        }

        if (_communicationData.length != committeeMembers.length) {
            revert InvalidCommunicationDataLength(_communicationData.length, committeeMembers.length);
        }

        for (uint256 i = 0; i < _communicationData.length; i++) {
            bool isEmpty = BytesHelper.isArrayEmpty(_communicationData[i].data);

            if (msg.sender == committeeMembers[i].memberAddress) {
                if (!isEmpty) {
                    revert InvalidNonZeroCommunicationData(i, _communicationData[i]);
                }
            } else {
                if (isEmpty) {
                    revert InvalidZeroCommunicationData(i, _communicationData[i]);
                }
            }

            communicationDataStorage.push(CommunicationData({data: _communicationData[i].data}));
        }

        pendingCommittee.missingCommunicationData--;
        emit MemberCommunicationDataDeposited(_committeeId, msg.sender, _communicationData);

        if (pendingCommittee.missingCommunicationData == 0) {
            emit AllCommunicationDataReady(_committeeId);
        }
    }

    /// @notice Gets the encrypted communication data for one member in a committee
    /// @dev This function returns the encrypted communication data (IP and Port) deposited for a particular member
    /// @param _committeeId The committee ID for the committee
    /// @param _memberAddress The address of the member we are requesting data for
    /// @return communicationData encrypted communication data (IP and Port) from the committee members
    /// @dev The order of the data corresponds to the order of members in the committee
    function getMemberCommunicationData(uint128 _committeeId, address _memberAddress)
        external
        view
        returns (CommunicationData[] memory communicationData)
    {
        _isInCommitteeOrRevert(_committeeId, msg.sender);

        CommitteeMember[] storage committeeMembers = committeesById[_committeeId].members;

        uint256 memberIndex = 0;
        for (uint256 i = 0; i < committeeMembers.length; i++) {
            if (committeeMembers[i].memberAddress == _memberAddress) {
                memberIndex = i;
                break;
            }
        }

        communicationData = new CommunicationData[](committeeMembers.length);
        for (uint256 i = 0; i < committeeMembers.length; i++) {
            if (committeesData[_committeeId][committeeMembers[i].memberAddress].communicationData.length != 0) {
                communicationData[i].data =
                    committeesData[_committeeId][committeeMembers[i].memberAddress].communicationData[memberIndex].data;
            }
            // else: leave as default zeros - member hasn't deposited data yet
        }
    }

    /// @notice Returns the pending committee for the stream
    /// @dev This function will revert if  there is no pending committee or if it's expired
    /// @param _streamId The stream ID to get the pending committee for
    /// @return committee The pending committee
    /// @return createdAt The timestamp when the pending committee was created
    /// @return missingData The number of members that have not provided their data yet
    function getPendingCommittee(uint64 _streamId)
        external
        view
        returns (Committee memory committee, uint256 createdAt, uint256 missingData)
    {
        // FIXME: Improve this function. It's returning redundant data.
        committee = _getPendingCommittee(_streamId);
        createdAt = committee.createdAt;
        missingData = committee.missingData;
    }

    /// @notice Returns the committee ID for a pending committee in the given stream
    /// @param _streamId The stream ID to get the pending committee ID for
    /// @return committeeId The committee ID of the pending committee
    function getPendingCommitteeId(uint64 _streamId) external view returns (uint128 committeeId) {
        return _getPendingCommitteeId(_streamId);
    }

    function _getPendingCommitteeId(uint64 _streamId) internal view returns (uint128 committeeId) {
        committeeId = pendingCommittees[_streamId];
        // NOTE: Slither flags this as dangerous-strict-equalities, but this is a false positive.
        if (committeeId == 0) {
            revert CommitteeIsNotPending(0);
        }
        return committeeId;
    }

    /// @notice Returns the number of members that have not deposited their communication data yet
    /// @param _committeeId The committee ID to check for missing communication data
    /// @return missingCommunicationData The number of members that have not deposited their communication data yet
    function getMissingCommunicationDataCount(uint128 _committeeId)
        external
        view
        returns (uint16 missingCommunicationData)
    {
        return committeesById[_committeeId].missingCommunicationData;
    }

    function _getPendingCommittee(uint64 _streamId) internal view returns (Committee storage) {
        return committeesById[_getPendingCommitteeId(_streamId)];
    }

    function _getPendingCommitteeById(uint128 _committeeId) internal view returns (Committee storage) {
        if (!committeesById[_committeeId].isPending) {
            revert CommitteeIsNotPending(_committeeId);
        }
        return committeesById[_committeeId];
    }

    /// @notice Checks if there is a pending committee for the stream and if it's expired
    /// @param _streamId The stream ID to check for a pending committee
    /// @return True if the pending committee exists and is expired
    function isPendingCommitteeExpired(uint64 _streamId) external view returns (bool) {
        uint256 createdAt = committeesById[pendingCommittees[_streamId]].createdAt;
        // If no pending committee in proccess we return false
        if (createdAt == 0) {
            return false;
        }
        // slither-disable-next-line timestamp
        return block.timestamp >= createdAt + pendingCommitteeTimeout;
    }

    function _deletePendingCommittee(uint64 _streamId) internal {
        committeesById[pendingCommittees[_streamId]].isPending = false; // Mark the committee as not pending
        pendingCommittees[_streamId] = 0; // Reset the pending committee ID
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
     * @return An array of committeeMemberCount CommitteeMembers containing the selected members.
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
        if (totalAvailableMembers < committeeMemberCount) {
            emit MissingMembers(denomination, committeeMemberCount, committeeMemberCount - totalAvailableMembers);
            return (new CommitteeMember[](0), PendingCommitteeStatus.NOT_ENOUGH_MEMBERS);
        }

        // Amount of each members per role in the committee
        // NOTE: Here assumme that committeeMemberCount > minCommitteeWatchtowers + minCommitteeOperators
        uint256 operatorsCommitteeAmount = (committeeMemberCount - minCommitteeWatchtowers > operatorsLength)
            ? operatorsLength
            : committeeMemberCount - minCommitteeWatchtowers;
        uint256 watchtowerCommitteeAmount = committeeMemberCount - operatorsCommitteeAmount;
        uint256 committeeMembersCounter = 0;

        // Create the final committee with committeeMemberCount members
        CommitteeMember[] memory selectedMembers = new CommitteeMember[](committeeMemberCount);

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
    /// @dev Only operators who have deposited their signatures nonces are eligible for take operations
    /// @param _committeeId The committee ID to get the operator from
    /// @param _signatureData Array of signature data for committee members
    /// @return The address of the next available operator for take operations
    /// @dev Reverts with TakeOperatorNotFound if no eligible operator is found
    function getOperatorTakeAddress(uint128 _committeeId, SignatureData[] calldata _signatureData)
        external
        onlyPegManager
        returns (address)
    {
        Committee storage committee = _getCommittee(_committeeId);
        uint256 membersLength = committee.members.length;

        for (uint256 i = 0; i < membersLength; i++) {
            // committee.operatorTakeIndex is the last operator that did the advancement of funds. Start from the next one.
            uint256 operatorTakeIndex = (committee.operatorTakeIndex + 1 + i) % membersLength;
            if (
                committee.members[operatorTakeIndex].role == Role.OPERATOR
                    && _signatureData[operatorTakeIndex].nonce.length > 0
            ) {
                committee.operatorTakeIndex = operatorTakeIndex;
                return committee.members[operatorTakeIndex].memberAddress;
            }
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
        if (committeeMemberCount < _minWatchtowers + minCommitteeOperators) {
            revert InvalidMinWatchtowers(committeeMemberCount, _minWatchtowers, minCommitteeOperators);
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
        if (committeeMemberCount < minCommitteeWatchtowers + _minOperators) {
            revert InvalidMinOperators(committeeMemberCount, minCommitteeWatchtowers, _minOperators);
        }
        minCommitteeOperators = _minOperators;
        emit CommitteeMinOperatorsUpdated(_minOperators);
    }

    /// @notice Sets the exact number of members required for a committee
    /// @dev Only callable by the contract owner
    /// @param _committeeMemberCount The exact number of members required for a committee
    function setCommitteeMemberCount(uint256 _committeeMemberCount) external onlyOwner {
        if (_committeeMemberCount == 0) {
            revert InvalidZeroValue();
        }
        if (_committeeMemberCount < minCommitteeWatchtowers + minCommitteeOperators) {
            revert InvalidMinMembers(_committeeMemberCount, minCommitteeWatchtowers, minCommitteeOperators);
        }
        committeeMemberCount = _committeeMemberCount;
        emit CommitteeMemberCountUpdated(_committeeMemberCount);
    }

    /// @notice Releases committee members from a packet and handles their staked balance
    /// @dev Called by PegManager to release committee members after packet completion
    /// @dev Members with reApply=true will be re-added as candidates, others get their balance as available
    /// @param _streamId The stream ID for the committee
    /// @param _packetNumber The packet number where the committee was active
    function releaseCommittee(uint64 _streamId, uint64 _packetNumber) external onlyPegManager {
        uint128 committeeId = streamManager.getCommitteeId(_streamId, _packetNumber);
        CommitteeMember[] memory committeeMembers = _getCommitteeMembers(committeeId);

        for (uint256 i = 0; i < committeeMembers.length; i++) {
            Member storage member = _getMember(committeeMembers[i].memberAddress);
            ApplicationData storage application = member.balance.applications[uint8(_streamId)];

            if (
                application.reApply && application.requestedRole == Role.NONE
                    && _committeesCandidatesHasSpace(StreamDenomination(_streamId), committeeMembers[i].role)
            ) {
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
        _onlyPegManager(msg.sender);
        _;
    }

    function _onlyPegManager(address _account) internal view {
        if (address(pegManager) != _account) {
            revert UnauthorizedAccount(_account);
        }
    }
}
