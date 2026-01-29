// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {BaseProxy} from "./BaseProxy.sol";
import {Pausable} from "./Pausable.sol";
import {IAccessManager} from "./interfaces/IAccessManager.sol";
import {
    Role,
    CommitteeMember,
    Committee,
    CommitteeRegistrySettings,
    ICommitteeRegistry,
    PendingCommitteeStatus,
    PendingCommitteeData,
    MemberRegistrationKeys,
    CommunicationData,
    UTXO
} from "./interfaces/ICommitteeRegistry.sol";
import {StreamDenomination, IStreamManager, Stream} from "./interfaces/IStreamManager.sol";
import {SignatureData} from "./interfaces/ISignatureManager.sol";
import {IMemberRegistry, MemberKeys} from "./interfaces/IMemberRegistry.sol";
import {BytesHelper} from "./libraries/BytesHelper.sol";
import {Constants} from "./libraries/Constants.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

/// @title CommitteeRegistry
/// @notice Manages committee formation, selection, and lifecycle for the union bridge system
/// @dev Handles committee creation, pending committee management, and coordination with MemberRegistry
contract CommitteeRegistry is ICommitteeRegistry, BaseProxy, ReentrancyGuardUpgradeable, Pausable {
    /// @notice Mapping of whitelisted addresses
    mapping(address => bool) internal whitelisted;
    /// @notice Minimum number of watchtowers required for a committee
    uint256 public minCommitteeWatchtowers;
    /// @notice Minimum number of operators required for a committee
    uint256 public minCommitteeOperators;
    /// @notice Minimum number of members required for a committee
    uint256 public committeeMemberCount;

    /// @notice Mapping of streamId to the pending committee id
    mapping(uint64 streamId => uint128) internal pendingCommittees;
    /// @notice Mapping of committeeId to committee data
    mapping(uint128 committeeId => Committee) internal committeesById;

    /// @notice Mapping of member addresses to their pending data
    mapping(uint128 committeeId => mapping(address memberAddress => PendingCommitteeData)) committeesData;

    /// @notice Mapping of streamId to flag indicating if a committee should be created
    mapping(uint64 streamId => bool createCommittee) public shouldCreateCommittee;

    /// @notice Whitelister for managing whitelisted addresses
    address public whitelister;
    /// @notice Stream manager contract for managing streams and packets
    IStreamManager streamManager;

    /// @notice Member registry contract for member management
    IMemberRegistry public memberRegistry;

    /// @notice Access manager contract for access control
    IAccessManager public accessManager;

    /// @notice Timeout in seconds for pending committee formation
    uint256 public pendingCommitteeTimeout;

    /// @notice Initializes the CommitteeRegistry contract
    /// @param _initialOwner The initial owner of the contract
    /// @param _memberRegistry The member registry contract address
    /// @param _settings The settings for the committee registry
    function initialize(
        address _initialOwner,
        IAccessManager _accessManager,
        IMemberRegistry _memberRegistry,
        IStreamManager _streamManager,
        CommitteeRegistrySettings memory _settings
    ) public virtual initializer {
        if (
            address(_accessManager) == address(0) || address(_memberRegistry) == address(0)
                || address(_streamManager) == address(0)
        ) {
            revert InvalidZeroAddress();
        }
        // slither-disable-next-line missing-zero-check
        whitelister = _initialOwner;
        accessManager = _accessManager;
        memberRegistry = _memberRegistry;
        streamManager = _streamManager;
        __BaseProxy_init(_initialOwner);
        __ReentrancyGuard_init();
        __Pauser_init(address(_accessManager));
        pendingCommitteeTimeout = _settings.pendingCommitteeTimeout; // Default timeout for pending committees
        for (uint64 i = 0; i < uint64(StreamDenomination.LENGTH); i++) {
            shouldCreateCommittee[i] = true;
        }
        minCommitteeWatchtowers = _settings.minCommitteeWatchtowers;
        minCommitteeOperators = _settings.minCommitteeOperators;
        committeeMemberCount = _settings.committeeMemberCount;
    }

    function _revertIfZero(uint256 _value) internal pure {
        if (_value == 0) {
            revert InvalidZeroValue();
        }
    }

    function isWhitelisted(address _address) external view returns (bool) {
        return whitelisted[_address];
    }

    function whitelistAddress(address _addressToWhitelist) external onlyWhitelister {
        address[] memory addressesToWhitelist = new address[](1);
        addressesToWhitelist[0] = _addressToWhitelist;

        _whitelistAddresses(addressesToWhitelist);
    }

    function whitelistAddresses(address[] memory _addressesToWhitelist) external onlyWhitelister {
        _whitelistAddresses(_addressesToWhitelist);
    }

    function _whitelistAddresses(address[] memory _addressesToWhitelist) internal {
        for (uint256 i = 0; i < _addressesToWhitelist.length; i++) {
            _whitelistAddress(_addressesToWhitelist[i]);
        }
    }

    function _whitelistAddress(address _addressToWhitelist) internal {
        if (whitelisted[_addressToWhitelist]) {
            return;
        }
        whitelisted[_addressToWhitelist] = true;
        emit AddressWhitelisted(_addressToWhitelist);
    }

    function unwhitelistAddress(address _addressToUnwhitelist) external onlyWhitelister {
        address[] memory addressesToUnwhitelist = new address[](1);
        addressesToUnwhitelist[0] = _addressToUnwhitelist;

        _unwhitelistAddresses(addressesToUnwhitelist);
    }

    function unwhitelistAddresses(address[] memory _addressesToUnwhitelist) external onlyWhitelister {
        _unwhitelistAddresses(_addressesToUnwhitelist);
    }

    function _unwhitelistAddresses(address[] memory _addressesToUnwhitelist) internal {
        uint256 denominationsLength = uint256(StreamDenomination.LENGTH);
        bool[] memory pendingCommitteesRestarted = new bool[](denominationsLength);

        for (uint256 i = 0; i < _addressesToUnwhitelist.length; i++) {
            _processUnwhitelisting(_addressesToUnwhitelist[i], pendingCommitteesRestarted);
        }
    }

    function _processUnwhitelisting(address _addressToUnwhitelist, bool[] memory _pendingCommitteesRestarted)
        internal
    {
        if (!whitelisted[_addressToUnwhitelist]) {
            return;
        }
        whitelisted[_addressToUnwhitelist] = false;
        emit AddressUnwhitelisted(_addressToUnwhitelist);

        _cleanupAfterUnwhitelisting(_addressToUnwhitelist, _pendingCommitteesRestarted);
    }

    function _cleanupAfterUnwhitelisting(address _addressToUnwhitelist, bool[] memory _pendingCommitteesRestarted)
        internal
    {
        _restartPendingCommitteesAfterUnwhitelisting(_addressToUnwhitelist, _pendingCommitteesRestarted);
        _cleanUpMembershipAfterUnwhitelisting(_addressToUnwhitelist);
    }

    function _restartPendingCommitteesAfterUnwhitelisting(
        address _addressToUnwhitelist,
        bool[] memory _pendingCommitteesRestarted
    ) internal {
        uint256 denominationsLength = uint256(StreamDenomination.LENGTH);

        for (uint256 j = 0; j < denominationsLength; j++) {
            StreamDenomination denomination = StreamDenomination(j);
            if (_isInPendingCommittee(_addressToUnwhitelist, denomination)) {
                uint64 streamId = uint64(denomination);
                if (!_pendingCommitteesRestarted[streamId]) {
                    _restartPendingCommittee(streamId);
                    _pendingCommitteesRestarted[streamId] = true;
                }
            }
        }
    }

    function _cleanUpMembershipAfterUnwhitelisting(address _addressToUnwhitelist) internal {
        uint256 denominationsLength = uint256(StreamDenomination.LENGTH);

        for (uint256 i = 0; i < denominationsLength; i++) {
            StreamDenomination denomination = StreamDenomination(i);
            if (_isSubscribedToStream(_addressToUnwhitelist, denomination)) {
                _unsubscribeFromStream(_addressToUnwhitelist, denomination);
            }
            if (_isInActiveCommittee(_addressToUnwhitelist, denomination)) {
                // slither-disable-next-line calls-loop
                memberRegistry.disableMemberReApplyForStream(_addressToUnwhitelist, denomination);
            }
        }
    }

    /// @notice Applies to participate in a stream with a specific role
    /// @dev Registers public keys, deposits required bond, and provides funding UTXO for the requested role
    /// @dev Only callable when contract is unpaused
    /// @param _stream The stream denomination to apply for
    /// @param _role The role requested in the committee
    /// @param _publicKeys Member registration public keys
    /// @param _fundingUTXO The Bitcoin UTXO that will be used for the member funding

    // Note: Event emission happens in _createCommittee() after external calls to trusted memberRegistry contract.
    // This is safe because memberRegistry is a trusted contract and the event accurately reflects final state.
    function applyToStream(
        StreamDenomination _stream,
        Role _role,
        MemberRegistrationKeys calldata _publicKeys,
        UTXO calldata _fundingUTXO
    ) external payable nonReentrant whenNotPaused onlyWhitelistedAddress {
        // Delegate member registration to MemberRegistry
        memberRegistry.applyToStream{value: msg.value}(_msgSender(), _stream, _role, _publicKeys, _fundingUTXO);

        // Check if committee creation is needed after successful application
        _createCommitteeAfterApplyToStream(_stream);
    }

    /// @notice Unsubscribes from a stream and sets the pre-staked balance as available
    /// @dev Only callable when contract is unpaused
    /// @param _denomination The stream denomination to unsubscribe from
    function unsubscribeFromStream(StreamDenomination _denomination) external whenNotPaused {
        address sender = _msgSender();
        if (_isInPendingCommittee(sender, _denomination)) {
            revert MemberIsInPendingCommittee(sender, _denomination);
        }

        _unsubscribeFromStream(sender, _denomination);
    }

    function _unsubscribeFromStream(address _sender, StreamDenomination _denomination) internal {
        // Delegate to MemberRegistry for the actual unsubscription logic
        // slither-disable-next-line calls-loop
        memberRegistry.unsubscribeFromStream(_sender, _denomination);
    }

    function _isSubscribedToStream(address _userAddress, StreamDenomination _denomination)
        internal
        view
        returns (bool)
    {
        // slither-disable-next-line calls-loop
        if (!memberRegistry.isMember(_userAddress)) {
            return false;
        }
        // slither-disable-next-line calls-loop
        Role role = memberRegistry.getMemberRequestedRole(_userAddress, _denomination);
        return role != Role.NONE;
    }

    function _isInPendingCommittee(address _memberAddress, StreamDenomination _denomination)
        internal
        view
        returns (bool)
    {
        uint64 streamId = uint64(_denomination);
        uint128 committeeId = pendingCommittees[streamId];
        // NOTE: Slither flags this as dangerous-strict-equalities, but this is a false positive.
        if (committeeId == 0) {
            return false; // No pending committee
        }
        return committeesData[committeeId][_memberAddress].inCommittee;
    }

    function _isInActiveCommittee(address _memberAddress, StreamDenomination _denomination)
        internal
        view
        returns (bool)
    {
        uint64 streamId = uint64(_denomination);
        // slither-disable-next-line calls-loop
        Stream memory stream = streamManager.getStreamById(streamId);
        // slither-disable-next-line calls-loop
        uint64 packetsLength = streamManager.getPacketsLength(streamId);

        for (uint64 i = stream.pegoutPacketPointer; i < packetsLength; i++) {
            // slither-disable-next-line calls-loop
            uint128 committeeId = streamManager.getCommitteeId(streamId, i);
            if (committeesData[committeeId][_memberAddress].inCommittee) {
                return true;
            }
        }
        return false;
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

    /// @dev Only callable when contract is unpaused
    function restartPendingCommittee(uint64 _streamId) external whenNotPaused {
        uint256 createdAt = _getPendingCommittee(_streamId).createdAt;

        // slither-disable-next-line timestamp
        if (block.timestamp < createdAt + pendingCommitteeTimeout) {
            revert PendingCommitteeNotExpired(_streamId, createdAt, createdAt + pendingCommitteeTimeout);
        }

        _restartPendingCommittee(_streamId);
    }

    function _restartPendingCommittee(uint64 _streamId) internal {
        // slither-disable-next-line reentrancy-no-eth reentrancy-benign
        _discardPendingCommittee(_streamId);
        _createCommittee(_streamId);
    }

    /// @notice Triggers the creation of a new committee for a stream if the timeout has expired
    /// @dev Only callable by PegManager contract
    /// @dev This function is called when the slot usage threshold is reached
    /// @param _streamId The stream ID to create a new committee for
    function createCommittee(uint64 _streamId) external {
        // Verify that the caller has permission to create a committee
        accessManager.canCreateCommittee(_msgSender());

        // NOTE: This method is called from the pegManager, so we should not revert.
        uint256 createdAt = committeesById[pendingCommittees[_streamId]].createdAt;

        if (createdAt != 0) {
            // slither-disable-next-line timestamp
            if (block.timestamp < createdAt + pendingCommitteeTimeout) {
                return;
            }

            // slither-disable-next-line reentrancy-no-eth reentrancy-benign
            _discardPendingCommittee(_streamId);
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
        // NOTE: Slither flags this as dangerous-strict-equalities, but this is a false positive.
        if (createdAt == 0) {
            return false;
        }

        // slither-disable-next-line timestamp
        if (block.timestamp >= createdAt + pendingCommitteeTimeout) {
            // slither-disable-next-line reentrancy-benign
            _discardPendingCommittee(_streamId);
            _createCommittee(_streamId);
        }

        return true;
    }

    // Note: State changes after external call to memberRegistry.selectCommittee() are necessary because
    // we need the returned committee member data to populate state. memberRegistry is a trusted contract
    // controlled by the same owner, making reentrancy attacks impossible.
    // slither-disable-next-line reentrancy-benign,reentrancy-events
    function _createCommittee(uint64 _streamId) internal returns (PendingCommitteeStatus) {
        // slither-disable-next-line reentrancy-benign,calls-loop
        (CommitteeMember[] memory committeeMembers, PendingCommitteeStatus status) = memberRegistry.selectCommittee(
            _streamId, minCommitteeWatchtowers, minCommitteeOperators, committeeMemberCount
        );
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
        committee.aggregatedKey = new bytes(0);
        committee.streamId = _streamId;
        committee.isPending = true;

        // Initialize the committee members here.
        // No need to initialize aggregatedKey, since it will be set by the members.
        for (uint256 i = 0; i < committeeMembers.length; i++) {
            // Copy committee members from memory to storage
            committee.members.push(committeeMembers[i]);

            // slither-disable-next-line calls-loop
            committee.fundingUTXOs.push(
                memberRegistry.getMemberFundingUTXO(_streamId, committeeMembers[i].memberAddress)
            );

            // Initialize committee users pending data
            committeesData[committeeId][committeeMembers[i].memberAddress].inCommittee = true;
        }
        // slither-disable-next-line reentrancy-events
        emit NewPendingCommittee(committeeId, committee);
        return PendingCommitteeStatus.SUCCESS;
    }

    function _isInCommitteeOrRevert(uint128 _committeeId, address _memberAddress) internal view {
        if (!committeesData[_committeeId][_memberAddress].inCommittee) {
            revert MemberNotInCommittee(_committeeId, _memberAddress);
        }
    }

    function isMemberInCommittee(uint128 _committeeId, address _memberAddress) external view returns (bool) {
        return committeesData[_committeeId][_memberAddress].inCommittee;
    }

    /// @notice Allows a member to deposit information for committee formation
    /// @dev Called by members to provide their aggregated key for a pending committee
    /// @dev Only callable when contract is unpaused
    /// @param _committeeId The ID of the pending committee
    /// @param _aggregatedKey The aggregated public key provided by the member
    function depositAggregatedKey(uint128 _committeeId, bytes memory _aggregatedKey) external whenNotPaused {
        address sender = _msgSender();
        Committee storage pendingCommittee = _getPendingCommitteeById(_committeeId);

        if (_aggregatedKey.length != 33) {
            revert InvalidAggregatedKeyLength(_aggregatedKey.length, 33);
        }

        if (keccak256(_aggregatedKey) == keccak256(new bytes(33))) {
            revert InvalidAggregatedKeyZero();
        }

        _isInCommitteeOrRevert(_committeeId, sender);

        if (committeesData[_committeeId][sender].aggregatedKey.length != 0) {
            revert MemberInfoAlreadyDeposited(_committeeId, sender);
        }

        committeesData[_committeeId][sender].aggregatedKey = _aggregatedKey;

        if (pendingCommittee.aggregatedKey.length == 0) {
            // Save the aggregated key for the committee
            pendingCommittee.aggregatedKey = _aggregatedKey;
        } else {
            if (keccak256(pendingCommittee.aggregatedKey) != keccak256(_aggregatedKey)) {
                // slither-disable-next-line reentrancy-no-eth reentrancy-benign
                _discardPendingCommittee(pendingCommittee.streamId);
                _createCommittee(pendingCommittee.streamId); // Ignoring checks
                return;
            }
        }

        pendingCommittee.missingData--;
        emit MemberInfoDeposited(_committeeId, sender, _aggregatedKey);
        if (pendingCommittee.missingData != 0) {
            // Committee is not completed yet
            return;
        }

        // Follow checks-effects-interactions pattern: state changes before external calls
        uint64 streamId = pendingCommittee.streamId;
        _resetPendingCommittee(streamId);
        emit NewCommittee(_committeeId, pendingCommittee);

        // External calls last to prevent reentrancy
        memberRegistry.stakePreStakedCandidatesBalance(
            pendingCommittee.members,
            StreamDenomination(pendingCommittee.streamId),
            streamManager.getPacketsLength(pendingCommittee.streamId)
        );

        bytes32[] memory disputeKeys = _getCommitteeDisputeKeys(_committeeId);
        streamManager.createNewPacket(
            pendingCommittee.streamId, _committeeId, pendingCommittee.aggregatedKey, disputeKeys
        );
    }

    /// @notice Allows a member to deposit communication data for its respective pending committee
    /// @dev Called by members to provide their communication data for a pending committee
    /// @dev Only callable when contract is unpaused
    /// @param _committeeId The ID of the pending committee
    /// @param _communicationData The communication data to be added
    function depositCommunicationData(uint128 _committeeId, CommunicationData[] memory _communicationData)
        external
        whenNotPaused
    {
        address sender = _msgSender();
        Committee storage pendingCommittee = _getPendingCommitteeById(_committeeId);

        CommunicationData[] storage communicationDataStorage = committeesData[_committeeId][sender].communicationData;
        CommitteeMember[] storage committeeMembers = pendingCommittee.members;

        _isInCommitteeOrRevert(_committeeId, sender);

        if (communicationDataStorage.length != 0) {
            revert MemberAlreadyDepositedCommunicationData(_committeeId, sender, communicationDataStorage.length);
        }

        if (_communicationData.length != committeeMembers.length) {
            revert InvalidCommunicationDataLength(_communicationData.length, committeeMembers.length);
        }

        // Verify that the status of the pending committee has not changed to expired.
        // slither-disable-next-line timestamp
        if (block.timestamp >= pendingCommittee.createdAt + pendingCommitteeTimeout) {
            revert PendingCommitteeExpired(
                _committeeId,
                block.timestamp,
                pendingCommittee.createdAt,
                pendingCommittee.createdAt + pendingCommitteeTimeout
            );
        }

        for (uint256 i = 0; i < _communicationData.length; i++) {
            bool isEmpty = BytesHelper.isArrayEmpty(_communicationData[i].data);

            if (sender == committeeMembers[i].memberAddress) {
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
        emit MemberCommunicationDataDeposited(_committeeId, sender, _communicationData);

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
        _isInCommitteeOrRevert(_committeeId, _msgSender());

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
    /// @dev This function will revert if there is no pending committee or if it's expired
    /// @param _streamId The stream ID to get the pending committee for
    /// @return committee The pending committee (contains createdAt and missingData fields)
    function getPendingCommittee(uint64 _streamId) external view returns (Committee memory) {
        return _getPendingCommittee(_streamId);
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
        // NOTE: Slither flags this as dangerous-strict-equalities, but this is a false positive.
        if (createdAt == 0) {
            return false;
        }
        // slither-disable-next-line timestamp
        return block.timestamp >= createdAt + pendingCommitteeTimeout;
    }

    function _resetPendingCommittee(uint64 _streamId) internal {
        committeesById[pendingCommittees[_streamId]].isPending = false; // Mark the committee as not pending
        pendingCommittees[_streamId] = 0; // Clear the pending committee corresponding to the stream id
    }

    function _discardPendingCommittee(uint64 _streamId) internal {
        Committee storage pendingCommittee = committeesById[pendingCommittees[_streamId]];
        CommitteeMember[] memory committeeMembers = pendingCommittee.members;

        StreamDenomination denomination = StreamDenomination(_streamId);
        for (uint256 i = 0; i < committeeMembers.length; i++) {
            CommitteeMember memory member = committeeMembers[i];
            if (whitelisted[member.memberAddress]) {
                // slither-disable-next-line reentrancy-no-eth,reentrancy-benign,calls-loop
                memberRegistry.reAddCandidateToStream(denomination, member);
            }
        }
        _resetPendingCommittee(_streamId);
    }

    /// @notice Gets the operator dispute data (address and dispute public key) for operator-take operations
    /// @dev Rotates through committee operators to distribute take responsibilities
    /// @dev Only operators who have deposited their signatures nonces are eligible for take operations
    /// @param _committeeId The committee ID to get the operator from
    /// @param _signatureData Array of signature data for committee members
    /// @param _missingNonces Number of missing nonces
    /// @return operatorAddress The address of the next available operator for take operations
    /// @return disputePubKey The operator's dispute public key
    /// @dev Reverts with TakeOperatorNotFound if no eligible operator is found
    function getOperatorDisputeData(uint128 _committeeId, SignatureData[] calldata _signatureData, uint8 _missingNonces)
        external
        returns (address operatorAddress, bytes32 disputePubKey)
    {
        // Verify that the caller has permission to select a take operator
        accessManager.canSelectTakeOperator(_msgSender());
        Committee storage committee = _getCommittee(_committeeId);
        uint256 membersLength = committee.members.length;

        for (uint256 i = 0; i < membersLength; i++) {
            // committee.operatorTakeIndex is the last operator that did the advancement of funds. Start from the next one.
            uint256 operatorTakeIndex = (committee.operatorTakeIndex + 1 + i) % membersLength;

            if (
                // check if the operator is an operator
                // if there are missing nonces, check if the operator has deposited their nonce
                // if all nonces are present, check if the operator has deposited their signature
                committee.members[operatorTakeIndex].role == Role.OPERATOR
                    && (
                        _missingNonces == 0 // if all nonces are present
                            ? _signatureData[operatorTakeIndex].signature != bytes32(0)
                            : _signatureData[operatorTakeIndex].nonce.length > 0
                    )
            ) {
                // Update the operator take index
                committee.operatorTakeIndex = operatorTakeIndex;
                // Get the operator's address and dispute public key
                operatorAddress = committee.members[operatorTakeIndex].memberAddress;
                // slither-disable-next-line calls-loop
                disputePubKey = memberRegistry.getMemberPublicKeys(operatorAddress).covenantPubKey;
                return (operatorAddress, disputePubKey);
            }
        }

        revert TakeOperatorNotFound(_committeeId);
    }
    // ===================== Modifiers =====================

    /// @notice Modifier to restrict access to the whitelister
    /// @dev Reverts if the caller is not the whitelister
    modifier onlyWhitelister() {
        _onlyWhitelister(_msgSender());
        _;
    }

    function _onlyWhitelister(address _sender) internal view virtual {
        if (whitelister != _sender) {
            revert UnauthorizedWhitelister(_sender);
        }
    }

    modifier onlyWhitelistedAddress() {
        _onlyWhitelistedAddress(_msgSender());
        _;
    }

    function _onlyWhitelistedAddress(address _sender) internal view virtual {
        if (!whitelisted[_sender]) {
            revert NonWhitelistedAddress(_sender);
        }
    }

    // ===================== Administrative Functions =====================

    /// @notice Sets a new whitelister address
    /// @param _newWhitelister The new whitelister address
    /// @dev Only callable by the contract owner
    function setWhitelister(address _newWhitelister) public onlyOwner {
        if (_newWhitelister == address(0)) {
            revert InvalidZeroAddress();
        }
        whitelister = _newWhitelister;
        emit WhitelisterUpdated(_newWhitelister);
    }

    /// @notice Sets the pending committee timeout
    /// @dev Only callable by the contract owner
    /// @param _timeout The timeout in seconds for the pending committee
    function setPendingCommitteeTimeout(uint256 _timeout) external onlyOwner {
        _revertIfZero(_timeout);
        pendingCommitteeTimeout = _timeout;
        emit PendingCommitteeTimeoutUpdated(_timeout);
    }

    /// @notice Sets the minimum watchtowers required for a committee
    /// @dev Only callable by the contract owner
    /// @param _minWatchtowers The minimum watchtowers required for a committee
    function setCommitteeMinWatchtowers(uint256 _minWatchtowers) external onlyOwner {
        _revertIfZero(_minWatchtowers);
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
        _revertIfZero(_minOperators);
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
        _revertIfZero(_committeeMemberCount);
        if (_committeeMemberCount < minCommitteeWatchtowers + minCommitteeOperators) {
            revert InvalidMinMembers(_committeeMemberCount, minCommitteeWatchtowers, minCommitteeOperators);
        }
        if (_committeeMemberCount > Constants.MAX_COMMITTEE_MEMBER_COUNT) {
            revert InvalidMaxMembers(Constants.MAX_COMMITTEE_MEMBER_COUNT, _committeeMemberCount);
        }
        committeeMemberCount = _committeeMemberCount;
        emit CommitteeMemberCountUpdated(_committeeMemberCount);
    }

    /// @notice Releases committee members from a packet and handles their staked balance
    /// @dev Called by PegManager to release committee members after packet completion
    /// @dev Only callable by PegManager contract
    /// @dev Members with reApply=true will be re-added as candidates, others get their balance as available
    /// @param _streamId The stream ID for the committee
    /// @param _packetNumber The packet number where the committee was active
    function releaseCommittee(uint64 _streamId, uint64 _packetNumber) external {
        // Verify that the caller has permission to release a committee
        accessManager.canReleaseCommittee(_msgSender());
        uint128 committeeId = streamManager.getCommitteeId(_streamId, _packetNumber);
        CommitteeMember[] memory committeeMembers = _getCommitteeMembers(committeeId);

        emit CommitteeMembersReleased(_streamId, _packetNumber);
        // Delegate member release operations to MemberRegistry
        memberRegistry.releaseCommitteeMembers(committeeMembers, _streamId, _packetNumber);
    }

    /// @notice Gets the dispute keys (covenant public keys) for all committee members
    /// @param _committeeId The committee ID
    /// @return Array of dispute keys for all members
    function getCommitteeDisputeKeys(uint128 _committeeId) external view returns (bytes32[] memory) {
        return _getCommitteeDisputeKeys(_committeeId);
    }

    function _getCommitteeDisputeKeys(uint128 _committeeId) internal view returns (bytes32[] memory) {
        CommitteeMember[] memory committeeMembers = _getCommitteeMembers(_committeeId);
        bytes32[] memory disputeKeys = new bytes32[](committeeMembers.length);
        for (uint256 i = 0; i < committeeMembers.length; i++) {
            // slither-disable-next-line calls-loop
            MemberKeys memory keys = memberRegistry.getMemberPublicKeys(committeeMembers[i].memberAddress);
            disputeKeys[i] = keys.covenantPubKey;
        }
        return disputeKeys;
    }
}
