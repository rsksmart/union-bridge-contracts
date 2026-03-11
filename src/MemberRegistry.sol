// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {BaseProxy} from "./BaseProxy.sol";
import {Pausable} from "./Pausable.sol";
import {Role, CommitteeMember, UTXO, PendingCommitteeStatus} from "./interfaces/ICommitteeRegistry.sol";
import {
    IMemberRegistry,
    Member,
    MemberRegistrationKeys,
    MemberKeys,
    CompactPubKey,
    ApplicationData,
    Balance,
    ECDSAPublicKey,
    RSAPublicKey,
    RSA_PUBLIC_KEY_CHUNKS,
    PublicKeyType
} from "./interfaces/IMemberRegistry.sol";
import {StreamDenomination, IStreamManager} from "./interfaces/IStreamManager.sol";
import {Constants} from "./libraries/Constants.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {IRbtcBridge} from "./interfaces/IRbtcBridge.sol";
import {Secp256k1} from "./libraries/Secp256k1.sol";
import {BtcHelper} from "./libraries/BtcHelper.sol";
import {IAccessManager} from "./interfaces/IAccessManager.sol";

/// @title MemberRegistry
/// @notice Manages member registration, applications, and balance tracking for the union bridge system
/// @dev Handles member lifecycle operations including registration, candidacy, and balance management
contract MemberRegistry is IMemberRegistry, BaseProxy, ReentrancyGuardUpgradeable, Pausable {
    /// @notice Mapping of member addresses to their member data
    mapping(address => Member) internal members;

    /// @notice Mapping of stream denomination and role to list of candidate addresses
    mapping(StreamDenomination denomination => mapping(Role role => address[] membersAddress)) internal
        committeesCandidates;

    /// @notice Stream manager contract for managing streams and packets
    IStreamManager public streamManager;

    /// @notice Access manager contract for managing access control
    IAccessManager public accessManager;

    /// @notice RbtcBridge contract for Bitcoin block hash entropy
    IRbtcBridge public rbtcBridge;

    /// @notice Initializes the MemberRegistry contract
    /// @param _initialOwner The initial owner of the contract
    /// @param _accessManager The access manager contract address
    /// @param _rbtcBridge The rbtc bridge contract address
    function initialize(
        address _initialOwner,
        IAccessManager _accessManager,
        IRbtcBridge _rbtcBridge,
        IStreamManager _streamManager
    ) public virtual initializer {
        if (
            address(_accessManager) == address(0) || address(_rbtcBridge) == address(0)
                || address(_streamManager) == address(0)
        ) {
            revert InvalidZeroAddress();
        }
        accessManager = _accessManager;
        rbtcBridge = _rbtcBridge;
        streamManager = _streamManager;
        __BaseProxy_init(_initialOwner);
        __ReentrancyGuard_init();
        __Pauser_init(address(_accessManager));
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
        if (member.publicKeys.takePubKey.xOnly == bytes32(0)) {
            member = _registerMember(_address, _publicKeys);
        } else {
            // Check if the public keys are the same as the stored member's public keys
            _validateMemberKeyMatch(member, _publicKeys);
        }
        return member;
    }

    /// @inheritdoc IMemberRegistry
    function applyToStream(
        address _memberAddress,
        StreamDenomination _stream,
        Role _role,
        MemberRegistrationKeys calldata _publicKeys,
        UTXO calldata _fundingUTXO
    ) external payable {
        // Verify that the caller has permission to modify candidates for the stream
        accessManager.canModifyCandidatesForStream(_msgSender());
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

    /// @inheritdoc IMemberRegistry
    function unsubscribeFromStream(address _memberAddress, StreamDenomination _denomination) external {
        // Verify that the caller has permission to modify candidates for the stream
        accessManager.canModifyCandidatesForStream(_msgSender());

        _unsubscribeFromStream(_memberAddress, _denomination);
        emit MemberUnsubscribedFromStream(_memberAddress, _denomination);
    }

    /// @inheritdoc IMemberRegistry
    function withdrawAvailableBalance() external nonReentrant whenNotPaused {
        address sender = _msgSender();
        Member storage member = _getMember(sender);
        uint256 amount = member.balance.available;
        if (amount == 0) {
            revert NoAvailableBalanceToWithdraw(sender);
        }
        member.balance.available = 0;
        emit AvailableBalanceRetrieved(sender, amount);

        // Committee members are expected to be EOA
        // slither-disable-next-line arbitrary-send-eth,missing-zero-check,return-bomb
        (bool sent,) = payable(sender).call{value: amount, gas: 2300}("");
        if (!sent) {
            revert FailedToSendRSK(sender, amount);
        }
    }

    /// @inheritdoc IMemberRegistry
    function reAddCandidateToStream(StreamDenomination _denomination, CommitteeMember memory _member) external {
        // Verify that the caller has permission to modify candidates for the stream
        accessManager.canModifyCandidatesForStream(_msgSender());

        committeesCandidates[_denomination][_member.role].push(_member.memberAddress);
    }

    /// @inheritdoc IMemberRegistry
    function releaseCommitteeMembers(CommitteeMember[] memory _committeeMembers, uint64 _streamId, uint64 _packetNumber)
        external
    {
        // Verify that the caller has permission to modify candidates for the stream
        accessManager.canModifyCandidatesForStream(_msgSender());

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

        _validateECDSAKey(_publicKeys.disputeKey, PublicKeyType.DISPUTE);

        _validateRSAKey(_publicKeys.communicationKey, PublicKeyType.COMMUNICATION);
    }

    function _validateECDSAKey(ECDSAPublicKey calldata _key, PublicKeyType _type) internal pure {
        // Check if the public keys is on the curve
        if (!Secp256k1.isOnCurve(uint256(_key.publicKeyX), uint256(_key.publicKeyY))) {
            revert InvalidEDCSAPublicKey(_type, _key.publicKeyX, _key.publicKeyY);
        }

        // Validate signature is not zero
        if (_key.v == 0 || _key.r == bytes32(0) || _key.s == bytes32(0)) {
            revert InvalidZeroEDCSASignature(_type, _key);
        }

        // Use the uncompressed public key as the message
        bytes memory uncompressedPublicKey = abi.encodePacked(_key.publicKeyX, _key.publicKeyY);
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
        // Check if RSA public key is empty
        if (_isRSAKeyEmpty(_key.rsaPublicKey)) {
            revert InvalidZeroRSAPublicKey(_type);
        }
    }

    function _validateCompactPubKeyMatch(
        CompactPubKey storage _stored,
        ECDSAPublicKey calldata _submitted,
        PublicKeyType _keyType
    ) internal view {
        bytes1 parity = BtcHelper.parityFromY(_submitted.publicKeyY);
        if (_stored.xOnly != _submitted.publicKeyX || _stored.parity != parity) {
            revert PublicKeyMismatch(_keyType, _stored.xOnly, _submitted.publicKeyX);
        }
    }

    function _validateMemberKeyMatch(Member storage _member, MemberRegistrationKeys calldata _publicKeys)
        internal
        view
    {
        _validateCompactPubKeyMatch(_member.publicKeys.takePubKey, _publicKeys.takeKey, PublicKeyType.TAKE);
        _validateCompactPubKeyMatch(_member.publicKeys.disputePubKey, _publicKeys.disputeKey, PublicKeyType.DISPUTE);
        // COMMUNICATION key - compare RSA public key
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

        // Initialize Member public keys from the struct (compute parity from Y-coordinate)
        bytes1 takeParity = BtcHelper.parityFromY(_publicKeys.takeKey.publicKeyY);
        bytes1 disputeParity = BtcHelper.parityFromY(_publicKeys.disputeKey.publicKeyY);
        member.publicKeys.takePubKey = CompactPubKey({parity: takeParity, xOnly: _publicKeys.takeKey.publicKeyX});
        member.publicKeys.disputePubKey =
            CompactPubKey({parity: disputeParity, xOnly: _publicKeys.disputeKey.publicKeyX});
        member.publicKeys.communicationPubKey = _publicKeys.communicationKey;

        _initMemberBalance(member);

        // Emit event with the stored public keys
        emit NewMember(_memberAddress, member.publicKeys);
        return member;
    }

    /// @inheritdoc IMemberRegistry
    function getMemberTakePubKey(address _address) external view override returns (CompactPubKey memory) {
        return _getMember(_address).publicKeys.takePubKey;
    }

    /// @inheritdoc IMemberRegistry
    function getMemberComPubKey(address _address) external view override returns (RSAPublicKey memory) {
        return _getMember(_address).publicKeys.communicationPubKey;
    }

    /// @inheritdoc IMemberRegistry
    function getMemberDisputePubKey(address _address) external view override returns (bytes32) {
        return _getMember(_address).publicKeys.disputePubKey;
    }

    /// @inheritdoc IMemberRegistry
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

    /// @inheritdoc IMemberRegistry
    function getMemberRequestedRole(address _memberAddress, StreamDenomination _denomination)
        external
        view
        override
        returns (Role)
    {
        return _getMemberApplicationData(_memberAddress, _denomination).requestedRole;
    }

    /// @inheritdoc IMemberRegistry
    function getMemberAvailableBalance(address _address) external view override returns (uint256) {
        return _getMember(_address).balance.available;
    }

    /// @inheritdoc IMemberRegistry
    function getMemberPreStakedBalance(address _memberAddress, StreamDenomination _denomination)
        external
        view
        override
        returns (uint256)
    {
        return _getMemberApplicationData(_memberAddress, _denomination).preStaked;
    }

    /// @inheritdoc IMemberRegistry
    function getMemberStakedBalance(address _address, StreamDenomination _denomination, uint64 _packetNumber)
        external
        view
        override
        returns (uint256 amount)
    {
        return _getMember(_address).balance.staked[uint8(_denomination)][_packetNumber];
    }

    /// @inheritdoc IMemberRegistry
    function getMemberFundingUTXO(uint64 _streamId, address _memberAddress)
        external
        view
        override
        returns (UTXO memory)
    {
        return _getMemberApplicationData(_memberAddress, StreamDenomination(_streamId)).fundingUTXO;
    }

    /// @inheritdoc IMemberRegistry
    function isMember(address _address) external view returns (bool) {
        return members[_address].publicKeys.takePubKey.xOnly != bytes32(0);
    }

    function _getMember(address _address) internal view returns (Member storage member) {
        member = members[_address];
        if (member.publicKeys.takePubKey.xOnly == bytes32(0)) {
            revert MemberNotRegistered(_address);
        }
    }

    /// @inheritdoc IMemberRegistry
    function getCommitteeCandidates(StreamDenomination _denomination, Role _role)
        external
        view
        override
        returns (address[] memory)
    {
        return committeesCandidates[_denomination][_role];
    }

    /// @inheritdoc IMemberRegistry
    function setReApplyForStream(StreamDenomination _denomination, bool _reApply) external override whenNotPaused {
        _setReApplyForStream(_msgSender(), _denomination, _reApply);
    }

    /// @inheritdoc IMemberRegistry
    function disableMemberReApplyForStream(address _memberAddress, StreamDenomination _denomination) external {
        // Verify that the caller has permission to modify candidates for the stream
        accessManager.canModifyCandidatesForStream(_msgSender());

        bool reApply = false;
        _setReApplyForStream(_memberAddress, _denomination, reApply);
    }

    function _setReApplyForStream(address _memberAddress, StreamDenomination _denomination, bool _reApply) internal {
        ApplicationData storage applicationData = _getMemberApplicationData(_memberAddress, _denomination);
        applicationData.reApply = _reApply;

        emit MemberReApplyUpdated(_memberAddress, _denomination, _reApply);
    }

    /// @inheritdoc IMemberRegistry
    function getReApplyForStream(StreamDenomination _denomination) external view override returns (bool) {
        return _getMemberApplicationData(_msgSender(), _denomination).reApply;
    }

    // ===================== Committee Integration Functions =====================

    /// @inheritdoc IMemberRegistry
    function stakePreStakedCandidatesBalance(
        CommitteeMember[] memory _members,
        StreamDenomination _denomination,
        uint64 _packetNumber
    ) external {
        // Verify that the caller has permission to modify candidates for the stream
        accessManager.canModifyCandidatesForStream(_msgSender());

        for (uint256 i = 0; i < _members.length; i++) {
            _movePreStakedToStaked(_members[i].memberAddress, _denomination, _packetNumber);
        }
    }

    function _movePreStakedToStaked(address _memberAddress, StreamDenomination _denomination, uint64 _packetNumber)
        internal
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

    /// @notice Calculates a pseudo-random position within an array
    /// @dev Uses Bitcoin block hash as entropy source combined with array length
    /// @param _btcBlockHash The Bitcoin block hash used for entropy
    /// @param _arrayLength The length of the array to select from
    /// @return The pseudo-random position within the array (0 to _arrayLength - 1)
    function _getRandomPosition(bytes32 _btcBlockHash, uint256 _arrayLength) private pure returns (uint256) {
        // slither-disable-next-line weak-prng
        return uint256(keccak256(abi.encode(_btcBlockHash, _arrayLength))) % _arrayLength;
    }

    /// @inheritdoc IMemberRegistry
    function selectCommittee(
        uint64 _streamId,
        uint256 _minWatchtowers,
        uint256 _minOperators,
        uint256 _totalMemberCount
    ) external returns (CommitteeMember[] memory, PendingCommitteeStatus) {
        // Verify that the caller has permission to modify candidates for the stream
        accessManager.canModifyCandidatesForStream(_msgSender());

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
        address[] storage watchtowersCandidates = committeesCandidates[denomination][Role.WATCHTOWER];
        address[] storage operatorsCandidates = committeesCandidates[denomination][Role.OPERATOR];
        uint256 watchtowersLength = watchtowersCandidates.length;
        uint256 operatorsLength = operatorsCandidates.length;

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

        // Get Bitcoin block hash for entropy source
        // Using the Bitcoin blockchain's best block hash provides better security than RSK block hash
        // because Bitcoin miners cannot manipulate the selection of RSK committee members.
        // The BTC block hash is unpredictable from the RSK network's perspective.
        bytes32 btcBlockHash = rbtcBridge.getBestBlockHash();

        // True randomness is not required here. We only need enough unpredictability to ensure
        // different committee members get selected across multiple runs.
        // We use Fisher-Yates shuffle because it guarantees each index is selected exactly once.
        // This way we avoid index collisions and infinite loops.

        // Select random operators
        for (uint256 length = operatorsLength; length > operatorsLength - operatorsCommitteeAmount; length--) {
            uint256 randomPos = _getRandomPosition(btcBlockHash, length);

            selectedMembers[committeeMembersCounter++] =
                CommitteeMember({memberAddress: operatorsCandidates[randomPos], role: Role.OPERATOR});

            // Just move last position to replace random position. There is no need to swap values now.
            operatorsCandidates[randomPos] = operatorsCandidates[length - 1];
            operatorsCandidates.pop();
        }

        // Select random watchtowers
        for (uint256 length = watchtowersLength; length > watchtowersLength - watchtowerCommitteeAmount; length--) {
            uint256 randomPos = _getRandomPosition(btcBlockHash, length);

            selectedMembers[committeeMembersCounter++] =
                CommitteeMember({memberAddress: watchtowersCandidates[randomPos], role: Role.WATCHTOWER});

            // Just move last position to replace random position. There is no need to swap values now.
            watchtowersCandidates[randomPos] = watchtowersCandidates[length - 1];
            watchtowersCandidates.pop();
        }

        return (selectedMembers, PendingCommitteeStatus.SUCCESS);
    }

    // --- TESTNET ONLY: Force close committee functionality ---
    // TODO: Remove before mainnet deployment
    function forceReleaseCommitteeMembers_TESTNET(
        uint64 _streamId,
        uint64 _packetNumber,
        address[] memory _committeeMembersAddresses
    ) external onlyOwner {
        accessManager.revertIfNotTestnet();

        StreamDenomination denomination = StreamDenomination(_streamId);
        for (uint256 i = 0; i < _committeeMembersAddresses.length; i++) {
            // Move staked -> available (ignoring reApply flag)
            _moveStakedToAvailable(_committeeMembersAddresses[i], denomination, _packetNumber);
        }

        emit CommitteeMembersForceReleased(_streamId, _packetNumber);
    }

    /// @inheritdoc IMemberRegistry
    function forceExit_TESTNET(address _to) external onlyOwner {
        accessManager.revertIfNotTestnet();
        if (_to == address(0)) {
            revert InvalidZeroAddress();
        }
        uint256 amount = address(this).balance;

        emit ForceExit(_to, amount);

        // slither-disable-next-line return-bomb
        (bool sent,) = payable(_to).call{value: amount, gas: 30000}("");
        if (!sent) {
            revert FailedToSendRSK(_to, amount);
        }
    }
    // --- END TESTNET ONLY ---
}
