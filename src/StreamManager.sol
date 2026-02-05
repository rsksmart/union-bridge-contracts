// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {
    Stream,
    Packet,
    Slot,
    SlotLocation,
    SlotState,
    IStreamManager,
    StreamDenomination,
    StreamManagerSettings,
    StreamSettings,
    TimelockSettings
} from "./interfaces/IStreamManager.sol";
import {BaseProxy} from "./BaseProxy.sol";
import {IAccessManager} from "./interfaces/IAccessManager.sol";
import {Constants} from "src/libraries/Constants.sol";
import {BtcHelper} from "src/libraries/BtcHelper.sol";

import {IBitcoinManager} from "src/interfaces/IBitcoinManager.sol";
import {StreamPosition, PegStatus} from "src/interfaces/IPegCommonTypes.sol";
import {Role} from "src/interfaces/ICommitteeRegistry.sol";

/// @title Stream Manager
/// @notice Manages streams for the union bridge system
/// @dev Handles stream creation, packet management, and slot allocation for peg-in/peg-out operations
/// @dev Each stream represents a specific Bitcoin denomination with its own packet and slot management
contract StreamManager is IStreamManager, BaseProxy {
    Stream[] internal streams;
    /// @notice Mapping from stream ID to array of packets for that stream
    /// @dev Each packet contains committee information for processing transactions
    mapping(uint64 streamId => Packet[]) public packets;
    mapping(uint64 streamId => mapping(uint64 packetNumber => Slot[])) internal slots;

    /// @notice Mapping from stream ID to array of historical filled slots for that stream
    /// @dev The index should be used to get the next filled slot for peg-out processing
    mapping(uint64 streamId => SlotLocation[]) filledSlots;
    mapping(uint64 streamId => uint64 index) nextPegoutSlotIndex;
    mapping(uint64 streamId => uint64[]) activePackets;

    /// @notice Mapping from stream ID to know if there's a pegout in process for that stream
    mapping(uint64 streamId => bool pegoutInProcess) isPegoutInProcess;

    /// @notice Mapping from accept peg-in transaction ID to stream position
    /// @dev Tracks the position and status of each peg operation
    mapping(bytes32 acceptPeginTxid => StreamPosition) internal streamPositions;

    /// @notice The Bitcoin manager contract that handles Bitcoin transaction operations
    /// @dev Used to calculate enabler output scripts for packets
    IBitcoinManager public bitcoinManager;
    /// @notice The access manager contract that manages access control
    /// @dev Used to check access control for sensitive operations
    IAccessManager public accessManager;

    // Security bond percentage in 10_000 format (e.g. 1000 = 10%)
    mapping(Role role => uint16 percentage) public securityBondPercentage;
    uint256 public disablementPaymentsPerChallenge; // Payments for disablement challenges in wei
    uint256 public minimumSecurityDeposit; // Minimum security deposit in wei

    /// @notice Initializes the streams with their denominations and parameters
    /// @dev Creates streams for each denomination with default security bond and confirmation settings
    /// @param _initialOwner The address that will be set as the initial owner
    /// @param _accessManager The address of the AccessManager contract
    /// @param _bitcoinManager The BitcoinManager contract address
    /// @param _settings Struct with the settings for the StreamManager including security bond percentages
    function initialize(
        address _initialOwner,
        IAccessManager _accessManager,
        IBitcoinManager _bitcoinManager,
        StreamManagerSettings memory _settings
    ) public virtual initializer {
        // Validate that the addresses are not zero
        if (address(_accessManager) == address(0) || address(_bitcoinManager) == address(0)) {
            revert InvalidZeroAddress();
        }
        accessManager = _accessManager;
        bitcoinManager = _bitcoinManager;

        // Initialize the AccessManager contract
        __BaseProxy_init(_initialOwner);

        // Set the Stream Manager settings
        _setSecurityBondPercentage(Role.WATCHTOWER, _settings.securityBondPercentageWatchtower);
        _setSecurityBondPercentage(Role.OPERATOR, _settings.securityBondPercentageOperator);
        _setMinimumSecurityDeposit(_settings.minimumSecurityDeposit);
        _setDisablementPaymentsPerChallenge(_settings.disablementPaymentsPerChallenge);
    }

    /// @notice Initializes the streams with the given settings
    /// @param _streamSettings Array of structs with the settings for each stream including confirmation counts and timelock settings
    function initializeStreams(StreamSettings[] memory _streamSettings) external onlyOwner {
        // Validate the stream settings length
        uint256 length = _streamSettings.length;
        uint256 expectedLength = uint256(StreamDenomination.LENGTH);
        if (length != expectedLength) {
            revert InvalidStreamSettingsLength(length, expectedLength);
        }

        // Validate that the stream is not already initialized
        if (streams.length > 0) {
            revert StreamsAlreadyInitialized();
        }

        // Initialize the streams
        for (uint64 i = 0; i < length; i++) {
            // Validate the settings
            _validateTimelockSettings(_streamSettings[i].timelockSettings);
            if (
                _streamSettings[i].denomination == 0 || _streamSettings[i].peginConfirmations == 0
                    || _streamSettings[i].pegoutConfirmations == 0
            ) {
                revert InvalidStreamSettings(
                    i,
                    _streamSettings[i].denomination,
                    _streamSettings[i].peginConfirmations,
                    _streamSettings[i].pegoutConfirmations
                );
            }
            streams.push(
                Stream({
                    streamId: i,
                    denomination: _streamSettings[i].denomination,
                    peginPacketPointer: 0,
                    peginConfirmations: _streamSettings[i].peginConfirmations,
                    pegoutConfirmations: _streamSettings[i].pegoutConfirmations,
                    timelockSettings: _streamSettings[i].timelockSettings
                })
            );
            emit StreamCreated(i, _streamSettings[i].denomination);
        }
    }

    function _validateTimelockSettings(TimelockSettings memory _timelockSettings) internal pure {
        // Using a single if statement to reduce contract size
        if (
            _timelockSettings.shortTimelock == 0 || _timelockSettings.longTimelock == 0
                || _timelockSettings.opWonTimelock == 0 || _timelockSettings.claimGateTimelock == 0
                || _timelockSettings.inputNotRevealedTimelock == 0 || _timelockSettings.opNoCosignTimelock == 0
                || _timelockSettings.wtNoChallengeTimelock == 0 || _timelockSettings.requestPeginTimelock == 0
        ) {
            revert InvalidTimelockSettings(_timelockSettings);
        }
    }

    /// @inheritdoc IStreamManager
    function createNewPacket(
        uint64 _streamId,
        uint128 _committeeId,
        bytes calldata _committeePubKey,
        bytes32[] memory _disputeKeys
    ) external {
        // Verify that the caller has permission to create a packet
        accessManager.canCreatePacket(_msgSender());
        _createNewPacket(_streamId, _committeeId, _committeePubKey, _disputeKeys);
    }

    function _createNewPacket(
        uint64 _streamId,
        uint128 _committeeId,
        bytes memory _committeePubKey,
        bytes32[] memory _disputeKeys
    ) internal {
        // Calculate enabler script once for the whole packet
        bytes memory enablerScriptPubKey = bitcoinManager.getEnablerOutputP2TRScriptPub(_committeePubKey, _disputeKeys);

        uint64 packetNumber = uint64(packets[_streamId].length);
        packets[_streamId].push(
            Packet({
                packetNumber: packetNumber,
                committeeId: _committeeId,
                committeePubKey: _committeePubKey,
                enablerScriptPubKey: enablerScriptPubKey,
                finishedSlots: 0
            })
        );
        activePackets[_streamId].push(packetNumber);
        emit PacketCreated(_streamId, packetNumber);
    }

    /// @inheritdoc IStreamManager
    function getStream(uint64 _denomination) external view returns (Stream memory) {
        uint256 length = streams.length;
        for (uint256 i = 0; i < length; i++) {
            if (streams[i].denomination == _denomination) {
                return streams[i];
            }
        }
        revert StreamNotFoundByDenomination(_denomination);
    }

    /// @inheritdoc IStreamManager
    function getStreamById(uint64 _streamId) external view returns (Stream memory) {
        return _getStreamById(_streamId);
    }

    function _getStreamById(uint64 _streamId) internal view returns (Stream storage) {
        if (_streamId >= streams.length) {
            revert StreamNotFoundById(_streamId);
        }
        return streams[_streamId];
    }

    /// @inheritdoc IStreamManager
    function getStreamsLength() external view returns (uint64) {
        return uint64(streams.length);
    }

    /// @inheritdoc IStreamManager
    function getPacketsLength(uint64 _streamId) external view returns (uint64) {
        return uint64(packets[_streamId].length);
    }

    /// @inheritdoc IStreamManager
    function getPacket(uint64 _streamId, uint64 _packetNumber) public view returns (Packet memory) {
        if (_streamId >= streams.length) {
            revert StreamNotFoundById(_streamId);
        }

        if (packets[_streamId].length <= _packetNumber) {
            revert PacketOutOfBound(_packetNumber);
        }
        return packets[_streamId][_packetNumber];
    }

    /// @inheritdoc IStreamManager
    function getActivePackets(uint64 _streamId) external view returns (uint64[] memory) {
        return activePackets[_streamId];
    }

    /// @inheritdoc IStreamManager
    function getAvailablePeginCommitteeId(uint64 _streamId) external view returns (uint128) {
        Stream memory stream = streams[_streamId];
        if (stream.peginPacketPointer >= packets[_streamId].length) {
            return 0;
        }
        return packets[_streamId][stream.peginPacketPointer].committeeId;
    }

    function _getNextPegoutSlotLocation(uint64 _streamId) internal view returns (SlotLocation memory) {
        uint64 indexToUse = nextPegoutSlotIndex[_streamId];
        if (indexToUse >= filledSlots[_streamId].length) {
            revert NoFilledSlot(_streamId);
        }

        return filledSlots[_streamId][indexToUse];
    }

    /// @inheritdoc IStreamManager
    function getNextPegoutSlotLocation(uint64 _streamId) external view returns (SlotLocation memory) {
        return _getNextPegoutSlotLocation(_streamId);
    }

    /// @inheritdoc IStreamManager
    function hasPegoutInProcess(uint64 _streamId) external view returns (bool) {
        return isPegoutInProcess[_streamId];
    }

    /// @inheritdoc IStreamManager
    function lockSlot(uint64 _streamId) external returns (Slot memory, uint64) {
        // Verify that the caller has permission to modify the peg status
        accessManager.canModifyPegStatus(_msgSender());

        if (isPegoutInProcess[_streamId]) {
            revert PegoutInProcess(_streamId);
        }

        SlotLocation memory slotLocation = _getNextPegoutSlotLocation(_streamId);
        Slot storage slotToUse = slots[_streamId][slotLocation.packetId][slotLocation.slotId];
        slotToUse.state = SlotState.LOCKED;
        nextPegoutSlotIndex[_streamId]++;
        isPegoutInProcess[_streamId] = true;

        return (slotToUse, slotLocation.packetId);
    }

    /// @inheritdoc IStreamManager
    function getSlot(uint64 _streamId, uint64 _packetNumber, uint64 _slotNumber) external view returns (Slot memory) {
        return _getSlot(_streamId, _packetNumber, _slotNumber);
    }

    /// @inheritdoc IStreamManager
    function getPacketSlotsLength(uint64 _streamId, uint64 _packetNumber) external view returns (uint64) {
        return _getPacketSlotsLength(_streamId, _packetNumber);
    }

    /// @notice Gets the length of the slots in a packet
    /// @param _streamId The ID of the stream
    /// @param _packetNumber The packet number
    /// @return The length of the slots in the packet
    function _getPacketSlotsLength(uint64 _streamId, uint64 _packetNumber) internal view returns (uint64) {
        return uint64(slots[_streamId][_packetNumber].length);
    }

    /// @inheritdoc IStreamManager
    function reserveSlot(uint64 _streamId, uint64 _packetNumber) external returns (uint64) {
        // Verify that the caller has permission to modify the peg status
        accessManager.canModifyPegStatus(_msgSender());
        Stream storage stream = streams[_streamId];

        // If packet does not match with current packet being processed
        if (_packetNumber != stream.peginPacketPointer) {
            revert InvalidPeginPacketNumber(_streamId, _packetNumber);
        }

        uint64 slotId = _getPacketSlotsLength(_streamId, _packetNumber);
        slots[_streamId][_packetNumber].push(
            Slot({
                slotId: slotId,
                state: SlotState.RESERVED,
                acceptPeginTx: bytes32(0),
                acceptPeginAmount: 0,
                scriptPubKey: "",
                takeTx: ""
            })
        );
        emit SlotReserved(_streamId, _packetNumber, slotId);

        if (_getPacketSlotsLength(_streamId, _packetNumber) > Constants.SLOTS_PER_PACKET) {
            revert _InconsistentSlotsPerPacket(_streamId, _packetNumber, slots[_streamId][_packetNumber].length);
        }

        // Update the stream pegin pointer
        if (slots[_streamId][_packetNumber].length == Constants.SLOTS_PER_PACKET) {
            stream.peginPacketPointer++;
        }

        return slotId;
    }

    /// @inheritdoc IStreamManager
    function fillSlot(
        StreamPosition memory _streamPosition,
        uint64 _acceptPeginAmount,
        bytes32 _acceptPeginTx,
        bytes memory _scriptPubKey
    ) external {
        // Verify that the caller has permission to modify the peg status
        accessManager.canModifyPegStatus(_msgSender());
        Slot storage slot = _getSlot(_streamPosition.streamId, _streamPosition.packetNumber, _streamPosition.slotId);

        if (slot.state != SlotState.RESERVED) {
            revert SlotNotReserved(
                _streamPosition.streamId, _streamPosition.packetNumber, _streamPosition.slotId, slot.state
            );
        }

        slot.state = SlotState.FILLED;

        SlotLocation memory newFilledSlot =
            SlotLocation({packetId: _streamPosition.packetNumber, slotId: _streamPosition.slotId});
        filledSlots[_streamPosition.streamId].push(newFilledSlot);

        slot.acceptPeginTx = _acceptPeginTx;
        slot.acceptPeginAmount = _acceptPeginAmount;
        slot.scriptPubKey = _scriptPubKey;

        emit SlotFilled(
            _streamPosition.streamId,
            _streamPosition.packetNumber,
            _streamPosition.slotId,
            _acceptPeginTx,
            _acceptPeginAmount
        );
    }

    /// @inheritdoc IStreamManager
    function blockSlot(uint64 _streamId, uint64 _packetNumber, uint64 _slotId) external {
        // Verify that the caller has permission to modify the peg status
        accessManager.canModifyPegStatus(_msgSender());
        Slot storage slot = _getSlot(_streamId, _packetNumber, _slotId);

        if (slot.state != SlotState.RESERVED) {
            revert SlotNotBlockable(_streamId, _packetNumber, _slotId, slot.state);
        }

        slot.state = SlotState.BLOCKED;
        _markSlotAsFinished(_streamId, _packetNumber);
    }

    /// @inheritdoc IStreamManager
    function getCommitteeId(uint64 _streamId, uint64 _packetNumber) external view returns (uint128) {
        return getPacket(_streamId, _packetNumber).committeeId;
    }

    /// @inheritdoc IStreamManager
    function getCommitteePubKey(uint64 _streamId, uint64 _packetNumber) external view returns (bytes memory) {
        return getPacket(_streamId, _packetNumber).committeePubKey;
    }

    /// @inheritdoc IStreamManager
    function getEnablerScriptPubKey(uint64 _streamId, uint64 _packetNumber) external view returns (bytes memory) {
        return getPacket(_streamId, _packetNumber).enablerScriptPubKey;
    }

    /// @inheritdoc IStreamManager
    function completeSlot(StreamPosition memory _streamInfo, bytes32 _acceptPeginTxid, bytes32 _userTakeTx)
        external
        returns (bool packetClosed)
    {
        // Verify that the caller has permission to modify the peg status
        accessManager.canModifyPegStatus(_msgSender());
        Slot storage slot = _getSlot(_streamInfo.streamId, _streamInfo.packetNumber, _streamInfo.slotId);

        // Validate that the slot exists and is LOCKED or ADVANCED
        if (slot.state != SlotState.LOCKED && slot.state != SlotState.ADVANCED) {
            revert InvalidSlotState(slot.state, SlotState.LOCKED);
        }

        // Validate that the first input references the correct accept peg-in transaction
        if (slot.acceptPeginTx != _acceptPeginTxid) {
            revert InvalidAcceptPeginTxid(slot.acceptPeginTx, _acceptPeginTxid);
        }

        // Update the slot state to COMPLETED and store the user take tx id
        slot.state = SlotState.COMPLETED;
        slot.takeTx = _userTakeTx;
        isPegoutInProcess[_streamInfo.streamId] = false;
        packetClosed = _markSlotAsFinished(_streamInfo.streamId, _streamInfo.packetNumber);
    }

    function _markSlotAsFinished(uint64 _streamId, uint64 _packetNumber) internal returns (bool packetClosed) {
        Packet storage packet = packets[_streamId][_packetNumber];
        packet.finishedSlots++;

        packetClosed = _closePacketIfLastSlot(_streamId, _packetNumber);
    }

    function _closePacketIfLastSlot(uint64 _streamId, uint64 _packetNumber) internal returns (bool) {
        Packet storage packet = packets[_streamId][_packetNumber];
        if (packet.finishedSlots != Constants.SLOTS_PER_PACKET) {
            return false;
        }
        emit PacketClosed(_streamId, _packetNumber);
        _removeFromActivePackets(_streamId, _packetNumber);
        return true;
    }

    function _removeFromActivePackets(uint64 _streamId, uint64 _packetNumber) internal {
        uint64[] storage activePacketsForStream = activePackets[_streamId];
        for (uint256 i = 0; i < activePacketsForStream.length; i++) {
            if (_packetNumber == activePacketsForStream[i]) {
                activePacketsForStream[i] = activePacketsForStream[activePacketsForStream.length - 1];
                activePacketsForStream.pop();
                break;
            }
        }
    }

    function _getSlot(uint64 _streamId, uint64 _packetNumber, uint64 _slotId) internal view returns (Slot storage) {
        if (_packetNumber >= packets[_streamId].length) {
            revert NonExistentSlot(_streamId, _packetNumber, _slotId);
        }
        if (_slotId >= slots[_streamId][_packetNumber].length) {
            revert NonExistentSlot(_streamId, _packetNumber, _slotId);
        }
        return slots[_streamId][_packetNumber][_slotId];
    }

    /// @inheritdoc IStreamManager
    function advanceSlot(uint64 _streamId, uint64 _packetNumber, uint64 _slotId) external {
        // Verify that the caller has permission to modify the peg status
        accessManager.canModifyPegStatus(_msgSender());
        Slot storage slot = _getSlot(_streamId, _packetNumber, _slotId);

        // Validate that the slot exists and is in LOCKED state
        if (slot.state != SlotState.LOCKED) {
            revert InvalidSlotState(slot.state, SlotState.LOCKED);
        }

        // Update the slot state to ADVANCED
        slot.state = SlotState.ADVANCED;
    }

    /// @inheritdoc IStreamManager
    function getMinimumDeposit(StreamDenomination _denomination, Role _role) public view returns (uint256) {
        if (_role == Role.NONE) {
            revert InvalidRole(_role);
        }

        uint256 denominationValue = BtcHelper.satoshiToWei(uint256(streams[uint8(_denomination)].denomination));
        uint256 slotPercentage = denominationValue * securityBondPercentage[_role] / 10_000;
        uint256 challengeCost = minimumSecurityDeposit + disablementPaymentsPerChallenge;

        // Return the maximum
        return slotPercentage > challengeCost ? slotPercentage : challengeCost;
    }

    /// @inheritdoc IStreamManager
    function setTimelockSettings(uint64 _streamId, TimelockSettings memory _timelockSettings)
        external
        streamExists(_streamId)
        onlyOwner
    {
        _validateTimelockSettings(_timelockSettings);
        streams[_streamId].timelockSettings = _timelockSettings;
        emit TimelockSettingsUpdated(_streamId, _timelockSettings);
    }

    /// @inheritdoc IStreamManager
    function setPeginConfirmations(uint64 _streamId, uint8 _confirmations) external streamExists(_streamId) onlyOwner {
        if (_confirmations == 0) {
            revert InvalidPeginConfirmations(_confirmations);
        }

        streams[_streamId].peginConfirmations = _confirmations;
        emit PeginConfirmationsUpdated(_streamId, _confirmations);
    }

    /// @inheritdoc IStreamManager
    function setPegoutConfirmations(uint64 _streamId, uint8 _confirmations)
        external
        streamExists(_streamId)
        onlyOwner
    {
        if (_confirmations == 0) {
            revert InvalidPegoutConfirmations(_confirmations);
        }

        streams[_streamId].pegoutConfirmations = _confirmations;
        emit PegoutConfirmationsUpdated(_streamId, _confirmations);
    }

    /// @inheritdoc IStreamManager
    function setSecurityBondPercentage(Role _role, uint16 _percentage) external onlyOwner {
        _setSecurityBondPercentage(_role, _percentage);
    }

    function _setSecurityBondPercentage(Role _role, uint16 _percentage) internal {
        if (_role == Role.NONE) {
            revert InvalidRole(_role);
        }

        if (_percentage == 0 || _percentage > 10_000) {
            revert InvalidPercentage(_percentage);
        }

        securityBondPercentage[_role] = _percentage;
        emit SecurityBondPercentageUpdated(_role, _percentage);
    }

    /// @inheritdoc IStreamManager
    function setMinimumSecurityDeposit(uint256 _cost) external onlyOwner {
        _setMinimumSecurityDeposit(_cost);
    }

    function _setMinimumSecurityDeposit(uint256 _cost) internal {
        if (_cost == 0) {
            revert InvalidZeroValue();
        }
        minimumSecurityDeposit = _cost;
        emit MinimumSecurityDepositUpdated(_cost);
    }

    /// @inheritdoc IStreamManager
    function setDisablementPaymentsPerChallenge(uint256 _cost) external onlyOwner {
        _setDisablementPaymentsPerChallenge(_cost);
    }

    function _setDisablementPaymentsPerChallenge(uint256 _cost) internal {
        if (_cost == 0) {
            revert InvalidZeroValue();
        }
        disablementPaymentsPerChallenge = _cost;
        emit DisablementPaymentsPerChallengeUpdated(_cost);
    }

    /// @inheritdoc IStreamManager
    function setStreamPosition(bytes32 _acceptPeginTxid, StreamPosition memory _position) external {
        // Verify that the caller has permission to modify the peg status
        accessManager.canModifyPegStatus(_msgSender());
        streamPositions[_acceptPeginTxid] = _position;
        emit StreamPositionSet(_acceptPeginTxid, _position);
    }

    /// @inheritdoc IStreamManager
    function getStreamPosition(bytes32 _acceptPeginTxid) external view returns (StreamPosition memory) {
        return streamPositions[_acceptPeginTxid];
    }

    /// @inheritdoc IStreamManager
    function setPegStatus(bytes32 _acceptPeginTxid, PegStatus _newStatus) external {
        // Verify that the caller has permission to modify the peg status
        accessManager.canModifyPegStatus(_msgSender());
        streamPositions[_acceptPeginTxid].pegStatus = _newStatus;
        emit PegStatusUpdated(_acceptPeginTxid, _newStatus);
    }

    modifier streamExists(uint64 _streamId) {
        _streamExists(_streamId);
        _;
    }

    function _streamExists(uint64 _streamId) internal view {
        if (_streamId >= streams.length) {
            revert StreamNotFoundById(_streamId);
        }
    }

    // --- TESTNET ONLY: Force close packets functionality ---
    // TODO: Remove before mainnet deployment
    function restartStreamPointers_TESTNET(uint64 _streamId) external {
        // Verify that the caller has permission to invalidate stream pointers
        accessManager.canForceRestartStreamPointers(_msgSender());

        Stream storage stream = _getStreamById(_streamId);
        stream.peginPacketPointer = uint64(packets[_streamId].length);

        nextPegoutSlotIndex[_streamId] = 0;
        delete filledSlots[_streamId];

        // slither-disable-next-line reentrancy-events
        emit StreamPointersRestarted(_streamId);
    }

    function closePacket_TESTNET(uint64 _streamId, uint64 _packetNumber) external {
        accessManager.canForceCloseStreamPackets(_msgSender());
        _removeFromActivePackets(_streamId, _packetNumber);
    }
    // --- END TESTNET ONLY ---
}
