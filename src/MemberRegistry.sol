// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {BaseProxy} from "./BaseProxy.sol";
import {Pausable} from "./Pausable.sol";
import {
    Role,
    Member,
    CommitteeMember,
    ApplicationData,
    Balance,
    UTXO,
    ECDSAPublicKey,
    RSAPublicKey,
    MemberRegistrationKeys,
    MemberKeys,
    RSA_PUBLIC_KEY_CHUNKS,
    PublicKeyType,
    PendingCommitteeStatus
} from "./interfaces/ICommitteeRegistry.sol";
import {StreamDenomination, IStreamManager} from "./interfaces/IStreamManager.sol";
import {IMemberRegistry} from "./interfaces/IMemberRegistry.sol";
import {Constants} from "./libraries/Constants.sol";

/// @title MemberRegistry
/// @notice Manages member registration, applications, and balance tracking for the union bridge system
/// @dev Handles member lifecycle operations including registration, candidacy, and balance management
contract MemberRegistry is IMemberRegistry, BaseProxy, Pausable {
    /// @notice Mapping of member addresses to their member data
    mapping(address => Member) internal members;

    /// @notice Mapping of stream denomination and role to list of candidate addresses
    mapping(StreamDenomination denomination => mapping(Role role => address[] membersAddress)) internal
        committeesCandidates;

    /// @notice Stream manager contract for managing streams and packets
    IStreamManager public streamManager;

    /// @notice Committee registry contract for committee operations
    address public committeeRegistry;

    /// @notice Initializes the MemberRegistry contract
    /// @param _initialOwner The initial owner of the contract
    function initialize(address _initialOwner) public virtual initializer {
        __BaseProxy_init(_initialOwner);
        __Pausable_init();
    }

    function pause() external override(Pausable, IMemberRegistry) onlyPauser {
        _pause();
    }

    function unpause() external override(Pausable, IMemberRegistry) onlyPauser {
        _unpause();
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

    /// @notice Internal function to handle member application to stream
    /// @dev Called by CommitteeRegistry to handle member registration and candidacy
    /// @dev Only callable by CommitteeRegistry contract
    /// @param _memberAddress The address of the member applying
    /// @param _stream The stream denomination to apply for
    /// @param _role The role requested in the committee
    /// @param _publicKeys Member registration public keys
    /// @param _fundingUTXO The Bitcoin UTXO that will be used for the member funding
    function applyToStream(
        address _memberAddress,
        StreamDenomination _stream,
        Role _role,
        MemberRegistrationKeys calldata _publicKeys,
        UTXO calldata _fundingUTXO
    ) external payable onlyCommitteeRegistry {
        Member storage member = _getOrRegisterMember(_memberAddress, _publicKeys);

        if (_role == Role.NONE) {
            revert RequestedNoneRoleForStream(_stream);
        }
        if (_role == Role.OPERATOR) {
            _validateFundingUTXO(_fundingUTXO);
        }
        if (member.balance.applications[uint8(_stream)].requestedRole != Role.NONE) {
            revert MemberAlreadyRegisteredForStream(
                _memberAddress, _stream, _role, member.balance.applications[uint8(_stream)].requestedRole
            );
        }
        uint256 _depositAmount = msg.value;
        uint256 minDeposit = streamManager.getMinimumDeposit(_stream, _role);
        if (_depositAmount < minDeposit) {
            revert DespositBondTooLow(_depositAmount, minDeposit);
        }

        _registerCandidateToStream(_memberAddress, _stream, _role, _depositAmount, _fundingUTXO);
        emit NewSecurityBondDeposit(_memberAddress, _stream, _role, _depositAmount);
    }

    function _committeesCandidatesHasSpace(StreamDenomination _denomination, Role _role) internal view returns (bool) {
        return committeesCandidates[_denomination][_role].length < Constants.MAX_CANDIDATES_SIZE_PER_ROLE;
    }

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

    /// @notice Internal function to handle member unsubscription from stream
    /// @dev Called by CommitteeRegistry after pending committee checks
    /// @dev Only callable by CommitteeRegistry contract
    /// @param _memberAddress The address of the member unsubscribing
    /// @param _denomination The stream denomination to unsubscribe from
    function unsubscribeFromStream(address _memberAddress, StreamDenomination _denomination)
        external
        onlyCommitteeRegistry
    {
        _unsubscribeFromStream(_memberAddress, _denomination);
        emit MemberUnsubscribedFromStream(_memberAddress, _denomination);
    }

    /// @notice Withdraws available balance to the caller's address
    /// @dev Can only withdraw balance that is not pre-staked or staked
    /// @dev Only callable when contract is unpaused
    function withdrawAvailableBalance() external whenNotPaused {
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

    /// @notice Internal function to handle committee member release operations
    /// @dev Called by CommitteeRegistry after committee completion
    /// @dev Only callable by CommitteeRegistry contract
    /// @param _committeeMembers Array of committee members to release
    /// @param _streamId The stream ID
    /// @param _packetNumber The packet number
    function releaseCommitteeMembers(CommitteeMember[] memory _committeeMembers, uint64 _streamId, uint64 _packetNumber)
        external
        onlyCommitteeRegistry
    {
        for (uint256 i = 0; i < _committeeMembers.length; i++) {
            Member storage member = _getMember(_committeeMembers[i].memberAddress);
            ApplicationData storage application = member.balance.applications[uint8(_streamId)];

            if (
                application.reApply && application.requestedRole == Role.NONE
                    && _committeesCandidatesHasSpace(StreamDenomination(_streamId), _committeeMembers[i].role)
            ) {
                // If the member has reApply set to true, we should move the staked amount to pre-staked
                // and set them as candidate again (except the case they are already a candidate which can happen in some edge cases)
                _reapplyToStream(
                    _committeeMembers[i].memberAddress,
                    StreamDenomination(_streamId),
                    _packetNumber,
                    _committeeMembers[i].role
                );
            } else {
                // If the member has reApply set to false, we should move the staked amount to available
                _moveStakedToAvailable(_committeeMembers[i].memberAddress, StreamDenomination(_streamId), _packetNumber);
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

    function _removeFromCandidates(address _memberAddress, StreamDenomination _stream, Role _role) internal {
        address[] storage candidates = committeesCandidates[_stream][_role];
        uint256 length = candidates.length;

        for (uint256 i = 0; i < length; i++) {
            if (candidates[i] == _memberAddress) {
                candidates[i] = candidates[length - 1];
                candidates.pop();
                break;
            }
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

        // Get the expected signer address from the uncompressed public key
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

    /// @notice Gets the TAKE public key for a specific member
    /// @param _address The member's address
    /// @return The TAKE public key (x-coordinate only)
    function getMemberTakePubKey(address _address) external view override returns (bytes32) {
        return _getMember(_address).publicKeys.takePubKey;
    }

    /// @notice Gets the COMMUNICATION public key for a specific member
    /// @param _address The member's address
    /// @return The RSA COMMUNICATION public key
    function getMemberComPubKey(address _address) external view override returns (RSAPublicKey memory) {
        return _getMember(_address).publicKeys.communicationPubKey;
    }

    /// @notice Retrieves all public keys for a specific member
    /// @param _address The member's address
    /// @return publicKeys Member public keys structure
    function getMemberPublicKeys(address _address) external view override returns (MemberKeys memory publicKeys) {
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
        override
        returns (Role)
    {
        return _getMemberApplicationData(_memberAddress, _denomination).requestedRole;
    }

    /// @notice Gets the available balance for a member
    /// @param _address The member's address
    /// @return The available balance that can be withdrawn
    function getMemberAvailableBalance(address _address) external view override returns (uint256) {
        return _getMember(_address).balance.available;
    }

    /// @notice Gets the pre-staked balance for a member in a specific stream
    /// @param _memberAddress The member's address
    /// @param _denomination The stream denomination
    /// @return The pre-staked balance for the stream
    function getMemberPreStakedBalance(address _memberAddress, StreamDenomination _denomination)
        external
        view
        override
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
        override
        returns (uint256 amount)
    {
        return _getMember(_address).balance.staked[uint8(_denomination)][_packetNumber];
    }

    /// @notice Gets the funding UTXO for a member in a specific stream
    /// @param _streamId The stream ID
    /// @param _memberAddress The member's address
    /// @return The funding UTXO for the member's application to the stream
    function getMemberFundingUTXO(uint64 _streamId, address _memberAddress)
        external
        view
        override
        returns (UTXO memory)
    {
        return _getMemberApplicationData(_memberAddress, StreamDenomination(_streamId)).fundingUTXO;
    }

    function _getMember(address _address) internal view returns (Member storage member) {
        member = members[_address];
        if (member.publicKeys.takePubKey == bytes32(0)) {
            revert MemberNotRegistered(_address);
        }
    }

    /// @notice Gets all candidates for a specific role in a stream
    /// @param _denomination The stream denomination
    /// @param _role The role to get candidates for
    /// @return Array of candidate addresses
    function getCommitteeCandidates(StreamDenomination _denomination, Role _role)
        external
        view
        override
        returns (address[] memory)
    {
        return committeesCandidates[_denomination][_role];
    }

    /// @notice Sets the reapply flag for a member in a specific stream
    /// @dev Controls whether the member will automatically reapply after committee release
    /// @dev Only callable when contract is unpaused
    /// @param _denomination The stream denomination to set the flag for
    /// @param _reApply True to automatically reapply, false to receive balance as available
    function setReApplyForStream(StreamDenomination _denomination, bool _reApply) external override whenNotPaused {
        ApplicationData storage applicationData = _getMemberApplicationData(msg.sender, _denomination);
        applicationData.reApply = _reApply;

        emit MemberReApplyUpdated(msg.sender, _denomination, _reApply);
    }

    /// @notice Gets the reapply flag for a member in a specific stream
    /// @param _denomination The stream denomination to check
    /// @return True if the member will automatically reapply, false otherwise
    function getReApplyForStream(StreamDenomination _denomination) external view override returns (bool) {
        return _getMemberApplicationData(msg.sender, _denomination).reApply;
    }

    // ===================== Committee Integration Functions =====================

    /// @notice Removes candidates from pool and updates their balances
    /// @dev Called by CommitteeRegistry during committee formation
    /// @dev Only callable by Committee Registry contract
    /// @param _members Array of committee members
    /// @param _denomination The stream denomination
    /// @param _packetNumber The packet number
    function removeCandidatesAndUpdateBalance(
        CommitteeMember[] memory _members,
        StreamDenomination _denomination,
        uint64 _packetNumber
    ) external onlyCommitteeRegistry {
        for (uint256 i = 0; i < _members.length; i++) {
            Role role = _movePreStakedToStaked(_members[i].memberAddress, _denomination, _packetNumber);
            _removeFromCandidates(_members[i].memberAddress, _denomination, role);
        }
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

        member.balance.staked[uint8(_denomination)][_packetNumber] = originalData.preStaked;
        return originalData.requestedRole;
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

    /// @notice Randomly selects members to form a new committee for a given stream
    /// @dev Pseudo-randomly select at least minCommitteeWatchtowers watchtowers and minCommitteeOperators operators.
    /// @dev reverts with notEnoughWatchtowers if there are fewer than minCommitteeWatchtowers watchtower candidates
    /// @dev reverts with notEnoughOperators if there are fewer than minCommitteeOperators operator candidates
    /// @dev Only callable by CommitteeRegistry contract
    /// @param _streamId The ID of the stream to select committee members for (0-4)
    /// @return An array of committeeMemberCount CommitteeMembers containing the selected members.
    function selectCommittee(
        uint64 _streamId,
        uint256 _minWatchtowers,
        uint256 _minOperators,
        uint256 _totalMemberCount
    ) external onlyCommitteeRegistry returns (CommitteeMember[] memory, PendingCommitteeStatus) {
        return _selectCommittee(_streamId, _minWatchtowers, _minOperators, _totalMemberCount);
    }

    function _selectCommittee(
        uint64 _streamId,
        uint256 _minWatchtowers,
        uint256 _minOperators,
        uint256 _totalMemberCount
    ) internal returns (CommitteeMember[] memory, PendingCommitteeStatus) {
        // Get the stream denomination for the streamId
        StreamDenomination denomination = StreamDenomination(_streamId);

        // Get candidates per role.
        address[] memory watchtowers = committeesCandidates[denomination][Role.WATCHTOWER];
        address[] memory operators = committeesCandidates[denomination][Role.OPERATOR];
        uint256 watchtowersLength = watchtowers.length;
        uint256 operatorsLength = operators.length;

        // Ensure we have enough candidates
        if (watchtowersLength < _minWatchtowers) {
            emit MissingWatchtowers(denomination, _minWatchtowers, _minWatchtowers - watchtowersLength);
            return (new CommitteeMember[](0), PendingCommitteeStatus.NOT_ENOUGH_WATCHTOWERS);
        }

        if (operatorsLength < _minOperators) {
            emit MissingOperators(denomination, _minOperators, _minOperators - operatorsLength);
            return (new CommitteeMember[](0), PendingCommitteeStatus.NOT_ENOUGH_OPERATORS);
        }

        // Check if we have enough total members for the committee
        uint256 totalAvailableMembers = operatorsLength + watchtowersLength;
        if (totalAvailableMembers < _totalMemberCount) {
            emit MissingMembers(denomination, _totalMemberCount, _totalMemberCount - totalAvailableMembers);
            return (new CommitteeMember[](0), PendingCommitteeStatus.NOT_ENOUGH_MEMBERS);
        }

        // Amount of each members per role in the committee
        // NOTE: Here assumme that _totalMemberCount > _minWatchtowers + _minOperators
        uint256 operatorsCommitteeAmount = (_totalMemberCount - _minWatchtowers > operatorsLength)
            ? operatorsLength
            : _totalMemberCount - _minWatchtowers;
        uint256 watchtowerCommitteeAmount = _totalMemberCount - operatorsCommitteeAmount;
        uint256 committeeMembersCounter = 0;

        // Create the final committee with _totalMemberCount members
        CommitteeMember[] memory selectedMembers = new CommitteeMember[](_totalMemberCount);

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

    // ===================== Modifiers =====================

    /// @notice Modifier to restrict access to the CommitteeRegistry contract
    /// @dev Reverts if the caller is not the CommitteeRegistry
    modifier onlyCommitteeRegistry() {
        if (committeeRegistry != msg.sender) {
            revert UnauthorizedAccount(msg.sender);
        }
        _;
    }

    // ===================== Administrative Functions =====================

    /// @notice Sets the CommitteeRegistry contract address
    /// @dev Only callable by the contract owner
    /// @param _committeeRegistry The address of the CommitteeRegistry contract
    function setCommitteeRegistry(address _committeeRegistry) external override onlyOwner {
        if (_committeeRegistry == address(0)) {
            revert InvalidZeroAddress();
        }
        committeeRegistry = _committeeRegistry;
        emit CommitteeRegistryUpdated(_committeeRegistry);
        pauser = _committeeRegistry;
    }

    /// @notice Sets the Stream Manager contract address
    /// @dev Only callable by the contract owner
    /// @param _streamManager The address of the Stream Manager contract
    function setStreamManager(IStreamManager _streamManager) external override onlyOwner {
        if (address(_streamManager) == address(0)) {
            revert InvalidZeroAddress();
        }
        streamManager = _streamManager;
    }
}
