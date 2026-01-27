// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {
    Stream,
    Packet,
    Slot,
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
    mapping(uint64 streamId => mapping(uint64 packerNumber => Slot[])) internal slots;
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
    /// @param _streamSettings Array of structs with the settings for each stream including confirmation counts and timelock settings
    function initialize(
        address _initialOwner,
        IAccessManager _accessManager,
        IBitcoinManager _bitcoinManager,
        StreamManagerSettings memory _settings,
        StreamSettings[] memory _streamSettings
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

        // Validate the denominations
        uint256 length = _streamSettings.length;
        if (length > Constants.MAX_DENOMINATIONS_SIZE) {
            revert tooManyDenominations(Constants.MAX_DENOMINATIONS_SIZE);
        }

        // Validate the stream settings
        if (length == 0) {
            revert InvalidStreamSettingsLength(length);
        }
        // Initialize the streams
        for (uint64 i = 0; i < length; i++) {
            _validateTimelockSettings(_streamSettings[i].timelockSettings);
            if (_streamSettings[i].peginConfirmations == 0 || _streamSettings[i].pegoutConfirmations == 0) {
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
                    pegoutPacketPointer: 0,
                    pegoutSlotPointer: 0,
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

    /// @notice Creates a new packet for a stream
    /// @dev Can only be called by the CommitteeRegistry when a new committee is formed
    /// @param _streamId The ID of the stream to create a packet for
    /// @param _committeeId The ID of the committee that will process this packet
    /// @param _committeePubKey The public key of the committee for Bitcoin operations
    /// @param _disputeKeys The dispute keys (covenant public keys) for the committee members
    function createNewPacket(
        uint64 _streamId,
        uint128 _committeeId,
        bytes calldata _committeePubKey,
        bytes32[] memory _disputeKeys
    ) external {
        // Verify that the caller has permission to create a packet
        accessManager.requireCanCreatePacket(_msgSender());
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
                enablerScriptPubKey: enablerScriptPubKey
            })
        );
        emit PacketCreated(_streamId, packetNumber);
    }

    /// @notice Gets a stream by its denomination
    /// @param _denomination The Bitcoin denomination in satoshis
    /// @return The stream data for the given denomination
    function getStream(uint64 _denomination) external view returns (Stream memory) {
        uint256 length = streams.length;
        for (uint256 i = 0; i < length; i++) {
            if (streams[i].denomination == _denomination) {
                return streams[i];
            }
        }
        revert StreamNotFoundByDenomination(_denomination);
    }

    /// @notice Gets a stream by its ID
    /// @param _streamId The ID of the stream
    /// @return The stream data for the given ID
    function getStreamById(uint64 _streamId) external view returns (Stream memory) {
        return _getStreamById(_streamId);
    }

    function _getStreamById(uint64 _streamId) internal view returns (Stream storage) {
        if (_streamId >= streams.length) {
            revert StreamNotFoundById(_streamId);
        }
        return streams[_streamId];
    }

    /// @notice Gets the total number of streams
    /// @return The number of streams in the system
    function getStreamsLength() external view returns (uint64) {
        return uint64(streams.length);
    }

    /// @notice Gets the number of packets in a stream
    /// @param _streamId The ID of the stream
    /// @return The number of packets in the stream
    function getPacketsLength(uint64 _streamId) external view returns (uint64) {
        return uint64(packets[_streamId].length);
    }

    /// @notice Gets a specific packet from a stream
    /// @param _streamId The ID of the stream
    /// @param _packetNumber The packet number to retrieve
    /// @return The packet data
    function getPacket(uint64 _streamId, uint64 _packetNumber) public view returns (Packet memory) {
        if (_streamId >= streams.length) {
            revert StreamNotFoundById(_streamId);
        }

        if (packets[_streamId].length <= _packetNumber) {
            revert PacketOutOfBound(_packetNumber);
        }
        return packets[_streamId][_packetNumber];
    }

    /// @notice Gets the committee ID for the available pegin packet in a stream
    /// @param _streamId The ID of the stream
    /// @return The committee ID, or 0 if no current packet
    function getAvailablePeginCommitteeId(uint64 _streamId) external view returns (uint128) {
        Stream memory stream = streams[_streamId];
        if (stream.peginPacketPointer >= packets[_streamId].length) {
            return 0;
        }
        return packets[_streamId][stream.peginPacketPointer].committeeId;
    }

    function _findNextFilledSlot(uint64 _streamId) internal returns (Slot storage) {
        uint256 packetCount = packets[_streamId].length;
        // No packets created yet
        if (packetCount == 0) {
            revert NoPacketAvailable(_streamId);
        }

        Stream storage stream = streams[_streamId];

        // Loop through packets to find the next non-blocked slot
        while (stream.pegoutPacketPointer < packetCount) {
            // Get the packet slots for easier access
            Slot[] storage packetSlots = slots[_streamId][stream.pegoutPacketPointer];

            // Skip over any BLOCKED slots
            while (
                stream.pegoutSlotPointer < packetSlots.length
                    && packetSlots[stream.pegoutSlotPointer].state == SlotState.BLOCKED
            ) {
                stream.pegoutSlotPointer++;
            }

            // If we've reached the packet boundary, move to next packet
            if (stream.pegoutSlotPointer >= Constants.SLOTS_PER_PACKET) {
                stream.pegoutPacketPointer++;
                stream.pegoutSlotPointer = 0;
                continue;
            }

            // If we've exhausted all slots in this packet, no filled slot available
            if (stream.pegoutSlotPointer >= packetSlots.length) {
                revert NoFilledSlot(_streamId);
            }

            // Found a non-blocked slot revert if not filled
            Slot storage currentSlot = packetSlots[stream.pegoutSlotPointer];
            if (currentSlot.state != SlotState.FILLED) {
                if (currentSlot.state == SlotState.RESERVED) {
                    revert NoFilledSlot(_streamId);
                } else {
                    revert PegoutInProcess(_streamId);
                }
            }
            return currentSlot;
        }

        // If we've exhausted all packets without finding a non-blocked slot
        // stream.pegoutPacketPointer >= packetCount
        revert NoFilledSlot(_streamId);
    }

    /// @notice Returns the first filled slot, locks it, and updates the peg-out pointers
    /// @notice Reverts if a pegout is already in progress for the same stream
    /// @dev Can only be called by the PegManager
    /// @param _streamId The ID of the stream
    /// @return slot The locked slot data
    /// @return packet The packet number containing the slot
    function lockSlot(uint64 _streamId) external returns (Slot memory, uint64) {
        // Verify that the caller has permission to modify the peg status
        accessManager.requireCanModifyPegStatus(_msgSender());
        Stream storage stream = streams[_streamId];

        // Find the next filled slot, skipping blocked slots
        Slot storage currentSlot = _findNextFilledSlot(_streamId);
        currentSlot.state = SlotState.LOCKED;

        return (currentSlot, stream.pegoutPacketPointer);
    }

    /// @notice Gets a specific slot from a stream and packet
    /// @param _streamId The ID of the stream
    /// @param _packetNumber The packet number
    /// @param _slotNumber The slot number within the packet
    /// @return The slot data
    function getSlot(uint64 _streamId, uint64 _packetNumber, uint64 _slotNumber) external view returns (Slot memory) {
        return _getSlot(_streamId, _packetNumber, _slotNumber);
    }

    /// @notice Gets the length of the slots in a packet
    /// @param _streamId The ID of the stream
    /// @param _packetNumber The packet number
    /// @return The length of the slots in the packet
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

    /// @notice Reserves a slot for a peg-in request
    /// @dev Creates a new slot with RESERVED state during request peg-in
    /// @param _streamId The ID of the stream
    /// @param _packetNumber The packet number
    /// @return The slot ID that was reserved
    function reserveSlot(uint64 _streamId, uint64 _packetNumber) external returns (uint64) {
        // Verify that the caller has permission to modify the peg status
        accessManager.requireCanModifyPegStatus(_msgSender());
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

    /// @notice Fills a slot with accept peg-in transaction information
    /// @dev Updates the slot state from RESERVED to FILLED and stores transaction details
    /// @dev This is called by PeginManager contract
    /// @param _stream The struct containing the stream, packet, and slot information
    /// @param _acceptPeginAmount The amount of the accept peg-in transaction
    /// @param _acceptPeginTx The hash of the accept peg-in transaction
    /// @param _scriptPubKey The script pub key for the taptree output
    function fillSlot(
        StreamPosition memory _stream,
        uint64 _acceptPeginAmount,
        bytes32 _acceptPeginTx,
        bytes memory _scriptPubKey
    ) external {
        // Verify that the caller has permission to modify the peg status
        accessManager.requireCanModifyPegStatus(_msgSender());
        Slot storage slot = _getSlot(_stream.streamId, _stream.packetNumber, _stream.slotId);

        if (slot.state != SlotState.RESERVED) {
            revert SlotNotReserved(_stream.streamId, _stream.packetNumber, _stream.slotId, slot.state);
        }

        slot.state = SlotState.FILLED;
        slot.acceptPeginTx = _acceptPeginTx;
        slot.acceptPeginAmount = _acceptPeginAmount;
        slot.scriptPubKey = _scriptPubKey;

        emit SlotFilled(_stream.streamId, _stream.packetNumber, _stream.slotId, _acceptPeginTx, _acceptPeginAmount);
    }

    /// @notice Blocks a reserved slot due to timeout or refund proof
    /// @dev Updates the slot state from RESERVED to BLOCKED
    /// @param _streamId The ID of the stream
    /// @param _packetNumber The packet number
    /// @param _slotId The ID of the slot to block
    function blockSlot(uint64 _streamId, uint64 _packetNumber, uint64 _slotId) external {
        // Verify that the caller has permission to modify the peg status
        accessManager.requireCanModifyPegStatus(_msgSender());
        Slot storage slot = _getSlot(_streamId, _packetNumber, _slotId);

        if (slot.state != SlotState.RESERVED) {
            revert SlotNotBlockable(_streamId, _packetNumber, _slotId, slot.state);
        }

        slot.state = SlotState.BLOCKED;
    }

    /// @notice Gets the committee ID for a specific packet
    /// @param _streamId The ID of the stream
    /// @param _packetNumber The packet number
    /// @return The committee ID for the packet
    function getCommitteeId(uint64 _streamId, uint64 _packetNumber) external view returns (uint128) {
        return getPacket(_streamId, _packetNumber).committeeId;
    }

    /// @notice Gets the committee public key for a specific packet
    /// @param _streamId The ID of the stream
    /// @param _packetNumber The packet number
    /// @return bytes The committee public key for the packet
    function getCommitteePubKey(uint64 _streamId, uint64 _packetNumber) external view returns (bytes memory) {
        return getPacket(_streamId, _packetNumber).committeePubKey;
    }

    /// @notice Gets the enabler script public key for a specific packet
    /// @param _streamId The ID of the stream
    /// @param _packetNumber The packet number
    /// @return bytes The enabler script public key for the packet
    function getEnablerScriptPubKey(uint64 _streamId, uint64 _packetNumber) external view returns (bytes memory) {
        return getPacket(_streamId, _packetNumber).enablerScriptPubKey;
    }

    /// @notice Marks a slot as completed and stores the UserTake transaction id
    /// @dev Can only be called by the PegManager
    /// @dev Moves the pegout slot pointer to the next slot
    /// @param _streamId The ID of the stream
    /// @param _packetNumber The packet number
    /// @param _slotId The slot ID
    /// @param _acceptPeginTxid The hash of the accept peg-in transaction
    /// @param _userTakeTx The hash of the UserTake transaction
    function completeSlot(
        uint64 _streamId,
        uint64 _packetNumber,
        uint64 _slotId,
        bytes32 _acceptPeginTxid,
        bytes32 _userTakeTx
    ) external {
        // Verify that the caller has permission to modify the peg status
        accessManager.requireCanModifyPegStatus(_msgSender());
        Slot storage slot = _getSlot(_streamId, _packetNumber, _slotId);

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

        // Update the stream pegout pointers
        Stream storage stream = streams[_streamId];
        stream.pegoutSlotPointer++;
        if (stream.pegoutSlotPointer == Constants.SLOTS_PER_PACKET) {
            stream.pegoutPacketPointer++;
            stream.pegoutSlotPointer = 0;
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

    function advanceSlot(uint64 _streamId, uint64 _packetNumber, uint64 _slotId) external {
        // Verify that the caller has permission to modify the peg status
        accessManager.requireCanModifyPegStatus(_msgSender());
        Slot storage slot = _getSlot(_streamId, _packetNumber, _slotId);

        // Validate that the slot exists and is in LOCKED state
        if (slot.state != SlotState.LOCKED) {
            revert InvalidSlotState(slot.state, SlotState.LOCKED);
        }

        // Update the slot state to ADVANCED
        slot.state = SlotState.ADVANCED;
    }

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

    /// @notice Sets the timelock settings for a stream
    /// @dev Can only be called by the owner
    /// @param _streamId The ID of the stream
    /// @param _timelockSettings The timelock settings to set
    function setTimelockSettings(uint64 _streamId, TimelockSettings memory _timelockSettings)
        external
        streamExists(_streamId)
        onlyOwner
    {
        _validateTimelockSettings(_timelockSettings);
        streams[_streamId].timelockSettings = _timelockSettings;
        emit TimelockSettingsUpdated(_streamId, _timelockSettings);
    }

    /// @notice Sets the number of confirmations required for peg-in transactions
    /// @dev Can only be called by the owner
    /// @param _streamId The ID of the stream
    /// @param _confirmations The number of confirmations required
    function setPeginConfirmations(uint64 _streamId, uint8 _confirmations) external streamExists(_streamId) onlyOwner {
        if (_confirmations == 0) {
            revert InvalidPeginConfirmations(_confirmations);
        }

        streams[_streamId].peginConfirmations = _confirmations;
        emit PeginConfirmationsUpdated(_streamId, _confirmations);
    }

    /// @notice Sets the number of confirmations required for peg-out transactions
    /// @dev Can only be called by the owner
    /// @param _streamId The ID of the stream
    /// @param _confirmations The number of confirmations required
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

    /// @dev Sets the security bond percentage for a given role
    /// @param _role The role for which to set the security bond percentage
    /// @param _percentage The security bond percentage in 10_000 format (e.g. 1000 = 10%)
    /// @notice Reverts if the role is NONE or if the percentage is 0 or greater than 10_000
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

    /// @notice Sets the disablement payments cost per challenge, this is used to calculate the minimum deposit for a role
    /// @param _cost The new disablement payments per challenge in wei
    /// @dev Can only be called by the owner
    /// @dev Emits a DisablementPaymentsPerChallengeUpdated event on success
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

    /// @notice Stores the stream position for a given accept peg-in transaction ID
    /// @param _acceptPeginTxid The accept peg-in transaction ID
    /// @param _position The stream position to store
    /// @dev Only callable by the PegManager contract
    function setStreamPosition(bytes32 _acceptPeginTxid, StreamPosition memory _position) external {
        // Verify that the caller has permission to modify the peg status
        accessManager.requireCanModifyPegStatus(_msgSender());
        streamPositions[_acceptPeginTxid] = _position;
        emit StreamPositionSet(_acceptPeginTxid, _position);
    }

    /// @notice Retrieves the stream position for a given accept peg-in transaction ID
    /// @param _acceptPeginTxid The accept peg-in transaction ID
    /// @return The stream position associated with the transaction ID
    function getStreamPosition(bytes32 _acceptPeginTxid) external view returns (StreamPosition memory) {
        return streamPositions[_acceptPeginTxid];
    }

    /// @notice Updates only the peg status of an existing stream position
    /// @param _acceptPeginTxid The accept peg-in transaction ID
    /// @param _newStatus The new peg status to set
    /// @dev Only callable by the PegManager contract
    function setPegStatus(bytes32 _acceptPeginTxid, PegStatus _newStatus) external {
        // Verify that the caller has permission to modify the peg status
        accessManager.requireCanModifyPegStatus(_msgSender());
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
}
