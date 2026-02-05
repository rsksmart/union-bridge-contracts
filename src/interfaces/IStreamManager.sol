// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {Role} from "./ICommitteeRegistry.sol";
import {StreamPosition, PegStatus} from "./IPegCommonTypes.sol";

/// @notice Represents different Bitcoin denominations supported by the union bridge
/// @dev Each denomination corresponds to a specific stream for efficient fund management
enum StreamDenomination {
    /// @notice 0.001 BTC (100,000 satoshis)
    _0_001BTC,
    /// @notice 0.01 BTC (1,000,000 satoshis)
    _0_01BTC,
    /// @notice 0.1 BTC (10,000,000 satoshis)
    _0_1BTC,
    /// @notice 1 BTC (100,000,000 satoshis)
    _1BTC,
    /// @notice 10 BTC (1,000,000,000 satoshis)
    _10BTC,
    /// @notice This must always be the last element since it represents the total count of enum elements
    /// @dev Used for validation and iteration over the enum values
    LENGTH
}

/// @notice Represents the current state of a slot in the stream system
/// @dev Tracks the progression of funds through the slot lifecycle
enum SlotState {
    /// @notice Slot is reserved for a peg-in request awaiting committee acceptance
    RESERVED,
    /// @notice Slot has received a peg-in transaction and is filled with funds
    FILLED,
    /// @notice Slot is locked for peg-out processing
    LOCKED,
    /// @notice Slot is being advanced by an operator to the user
    ADVANCED,
    /// @notice Slot has been paid out
    COMPLETED,
    /// @notice Slot is blocked due to timeout or refund proof
    BLOCKED,
    /// @notice This must always be the last element since it represents the total count of enum elements
    /// @dev Used for validation and iteration over the enum values
    LENGTH
}

/// @notice Represents the location of a slot in the stream system
struct SlotLocation {
    uint64 packetId;
    uint64 slotId;
}

/// @notice Represents a slot within a packet that can hold funds
/// @dev Each slot corresponds to a specific UTXO in the Bitcoin network
struct Slot {
    /// @notice Unique identifier for the slot within its packet
    uint64 slotId;
    /// @notice Current state of the slot in the lifecycle
    SlotState state;
    /// @notice The scriptPubKey of the Accept Peg-in Output UTXO
    /// @dev This is the locking script that defines how the UTXO can be spent
    bytes scriptPubKey;
    /// @notice Transaction ID of peg-in transaction in the committee account
    /// @dev This is the Bitcoin transaction that filled this slot
    bytes32 acceptPeginTx;
    /// @notice The value of the accept peg-in transaction P2TR UTXO in satoshis
    uint64 acceptPeginAmount;
    /// @notice Transaction ID of the peg-out transaction to the user account.
    /// @dev The tx where the user is given the funds is stored there, which can be take 0 or take 1.
    bytes32 takeTx;
}

/// @notice Represents a packet within a stream that contains multiple slots
/// @dev Each packet is managed by a specific committee
struct Packet {
    /// @notice Unique identifier for the packet within its stream
    uint64 packetNumber;
    /// @notice The committee ID responsible for this packet
    /// @dev Each packet is managed by a specific committee of validators
    uint128 committeeId;
    /// @notice The internal key of the committee for this packet
    /// @dev This is the public key used for committee operations
    bytes committeePubKey;
    /// @notice The enabler output script for the packet
    /// @dev All slots in a packet share the same enabler script based on the committee
    bytes enablerScriptPubKey;
    /// @notice Counter of finished slots (completed or blocked)
    uint64 finishedSlots;
}

/// @notice Represents a stream that manages funds of a specific denomination
/// @dev Each stream handles a specific Bitcoin amount for efficient fund management
struct Stream {
    /// @notice Unique identifier for the stream
    uint64 streamId;
    /// @notice The denomination of the stream in satoshis
    /// @dev All funds in this stream must match this exact amount
    uint64 denomination;
    /// @notice Index pointing to the current packet with space for peg-in requests
    /// @dev Used to track which packet should receive new peg-in transactions
    uint64 peginPacketPointer;
    /// @notice Number of confirmations required for peg-in transactions
    /// @dev Ensures sufficient Bitcoin confirmations before accepting peg-ins
    uint8 peginConfirmations;
    /// @notice Number of confirmations required for peg-out transactions
    /// @dev Ensures sufficient Bitcoin confirmations before completing peg-outs
    uint8 pegoutConfirmations;
    /// @notice Timelock settings for the stream
    TimelockSettings timelockSettings;
}

/// @notice Bitcoin Timelock settings in blocks for the stream
/// @dev These are the timelock settings used to verify the Bitcoin transactions for the stream
struct TimelockSettings {
    /// @notice Short timelock in Bitcoin blocks used in Union protocol
    uint8 shortTimelock;
    /// @notice Long timelock in Bitcoin blocks used in Union protocol
    uint8 longTimelock;
    /// @notice Request peg-in timelock in Bitcoin blocks used in Union protocol
    /// @dev This is used for the user to recover the funds if the request peg-in timelock expires
    uint8 requestPeginTimelock;
    /// @notice Op won timelock in Bitcoin blocks used in Union protocol when operator wins the challenge
    /// @dev After this time, if no one challenges the operator, the operator wins the challenge
    uint8 opWonTimelock;
    /// @notice Claim gate timelock in Bitcoin blocks used in Union protocol when claim gate is triggered
    uint8 claimGateTimelock;
    /// @notice Input not revealed timelock in Bitcoin blocks used in Union protocol when input is not revealed in the challenge
    /// @dev This is the time the operator has to reveal the input in the challenge, if it does not, the watchtower wins the challenge
    uint8 inputNotRevealedTimelock;
    /// @notice Operator no cosign timelock in Bitcoin blocks used in Union protocol when operator does not cosign
    uint8 opNoCosignTimelock;
    /// @notice Watchtower no challenge timelock in Bitcoin blocks used in Union protocol when watchtower does not challenge the operator
    /// @dev This is the time the watchtower has to choose interval for the operator inputs (aka Challenger Tx), if it does not the watchtower is punished
    uint8 wtNoChallengeTimelock;
}

struct StreamSettings {
    /// @notice The denomination of the stream in satoshis
    /// @dev All funds in this stream must match this exact amount
    uint64 denomination;
    /// @notice Number of confirmations required for peg-in transactions
    uint8 peginConfirmations;
    /// @notice Number of confirmations required for peg-out transactions
    uint8 pegoutConfirmations;
    /// @notice Timelock settings for the Bitcoin transactions stored in the stream manager
    TimelockSettings timelockSettings;
}

struct StreamManagerSettings {
    /// @notice Percentage of security bond for the operator
    uint16 securityBondPercentageOperator;
    /// @notice Percentage of security bond for the watchtower
    uint16 securityBondPercentageWatchtower;
    /// @notice Minimum security deposit required for committee members (used to calculate challengeCost in getMinimumDeposit)
    uint256 minimumSecurityDeposit;
    /// @notice Amount of disablement payments per challenge (used to calculate challengeCost in getMinimumDeposit)
    uint256 disablementPaymentsPerChallenge;
}

/// @notice Interface for managing streams, packets, and slots in the union bridge
/// @dev This interface provides functions for organizing and tracking funds through the hierarchical structure
/// @dev Manages the lifecycle of funds from peg-in to peg-out through streams, packets, and slots
interface IStreamManager {
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
    ) external;

    /// @notice Gets a stream by its denomination
    /// @param _denomination The Bitcoin denomination in satoshis
    /// @return The stream data for the given denomination
    function getStream(uint64 _denomination) external view returns (Stream calldata);

    /// @notice Gets a stream by its ID
    /// @param _streamId The ID of the stream
    /// @return The stream data for the given ID
    function getStreamById(uint64 _streamId) external view returns (Stream calldata);

    /// @notice Gets the total number of streams in the system
    /// @return uint64 The number of streams
    function getStreamsLength() external view returns (uint64);

    /// @notice Gets the number of packets in a specific stream
    /// @param _streamId The ID of the stream
    /// @return uint64 The number of packets in the stream
    function getPacketsLength(uint64 _streamId) external view returns (uint64);

    /// @notice Gets a specific packet from a stream
    /// @param _streamId The ID of the stream
    /// @param _packetNumber The packet number to retrieve
    /// @return The packet data
    function getPacket(uint64 _streamId, uint64 _packetNumber) external view returns (Packet memory);

    /// @notice Gets the slot location that next pegout would have
    /// @dev Throws when there are no more filled slots - cant do a pegout
    /// @param _streamId The ID of the stream
    /// @return The slot location data
    function getNextPegoutSlotLocation(uint64 _streamId) external view returns (SlotLocation memory);

    /// @notice Returns whether there is a pegout in process associated to a stream
    /// @param _streamId The ID of the stream
    /// @return True if there is a pegout in process, false if not
    function hasPegoutInProcess(uint64 _streamId) external view returns (bool);

    /// @notice Returns the first filled slot, locks it, and updates the peg-out pointers
    /// @notice Reverts if a pegout is already in progress for the same stream
    /// @dev Can only be called by the PegManager
    /// @param _streamId The ID of the stream
    /// @return slot The locked slot data
    /// @return packetNumber The packet number containing the slot
    function lockSlot(uint64 _streamId) external returns (Slot memory, uint64 packetNumber);

    /// @notice Gets a specific slot from a stream and packet
    /// @param _streamId The ID of the stream
    /// @param _packetNumber The packet number
    /// @param _slotNumber The slot number within the packet
    /// @return The slot data
    function getSlot(uint64 _streamId, uint64 _packetNumber, uint64 _slotNumber) external view returns (Slot memory);

    /// @notice Reserves a slot for a peg-in request
    /// @dev Creates a new slot with RESERVED state during request peg-in
    /// @param _streamId The index of the stream
    /// @param _packetNumber The index of the packet within the stream
    /// @return uint64 The slot ID of the reserved slot
    function reserveSlot(uint64 _streamId, uint64 _packetNumber) external returns (uint64);

    /// @notice Fills a slot with accept peg-in transaction information
    /// @dev Updates the slot state from RESERVED to FILLED and stores transaction details
    /// @param _stream The struct containing the stream, packet, and slot information
    /// @param _acceptPeginAmount The amount of the accept peg-in transaction in satoshis
    /// @param _acceptPeginTx The transaction ID of the accept peg-in transaction
    /// @param _scriptPubKey The scriptPubKey of the accept peg-in taptree output
    function fillSlot(
        StreamPosition memory _stream,
        uint64 _acceptPeginAmount,
        bytes32 _acceptPeginTx,
        bytes memory _scriptPubKey
    ) external;

    /// @notice Blocks a reserved slot due to timeout or refund proof
    /// @dev Updates the slot state from RESERVED to BLOCKED and sets peg status to BLOCKED
    /// @dev Close the packet if blocked slot is the last one
    /// @param _acceptPeginTxid The accept peg-in transaction ID to block
    /// @return packetClosed Whether the packet was closed or not
    function blockSlot(bytes32 _acceptPeginTxid) external returns (bool packetClosed);

    /// @notice Gets the committee ID for a specific packet
    /// @param _streamId The ID of the stream
    /// @param _packetNumber The packet number
    /// @return uint128 The committee ID for the packet
    function getCommitteeId(uint64 _streamId, uint64 _packetNumber) external view returns (uint128);

    /// @notice Retrieves the committee public key for a specific packet
    /// @param _streamId The ID of the stream
    /// @param _packetNumber The index of the packet within the stream
    /// @return bytes The committee public key for this packet (33 bytes)
    function getCommitteePubKey(uint64 _streamId, uint64 _packetNumber) external view returns (bytes memory);

    /// @notice Retrieves the enabler script public key for a specific packet
    /// @param _streamId The ID of the stream
    /// @param _packetNumber The index of the packet within the stream
    /// @return bytes The enabler script public key for this packet
    function getEnablerScriptPubKey(uint64 _streamId, uint64 _packetNumber) external view returns (bytes memory);

    /// @notice Marks a slot as completed and stores the UserTake transaction id
    /// @dev Can only be called by the PegManager
    /// @dev Close the packet if completed slot is the last one
    /// @param _acceptPeginTxid The hash of the accept peg-in transaction
    /// @param _userTakeTx The hash of the UserTake transaction
    /// @return packetClosed Whether the packet was closed or not
    function completeSlot(bytes32 _acceptPeginTxid, bytes32 _userTakeTx) external returns (bool packetClosed);

    /// @notice Marks a slot as advanced by the operator to the user
    /// @dev Updates the slot state to ADVANCED and stores the operator's peg-out transaction
    /// @param _streamId The index of the stream
    /// @param _packetNumber The index of the packet within the stream
    /// @param _slotId The index of the slot within the packet
    function advanceSlot(uint64 _streamId, uint64 _packetNumber, uint64 _slotId) external;

    /// @notice Sets the number of confirmations required for peg-in transactions
    /// @dev Only callable by the contract owner
    /// @param _streamId The ID of the stream
    /// @param _confirmations The number of confirmations required for peg-in transactions
    function setPeginConfirmations(uint64 _streamId, uint8 _confirmations) external;

    /// @notice Sets the number of confirmations required for peg-out transactions
    /// @dev Only callable by the contract owner
    /// @param _streamId The ID of the stream
    /// @param _confirmations The number of confirmations required for peg-out transactions
    function setPegoutConfirmations(uint64 _streamId, uint8 _confirmations) external;

    /// @notice Gets the committee ID for the available pegin packet in a stream
    /// @param _streamId The ID of the stream
    /// @return The committee ID, or 0 if no current packet
    function getAvailablePeginCommitteeId(uint64 _streamId) external view returns (uint128);

    /// @notice Gets the minimum deposit required for a specific denomination and role
    /// @param _denomination The denomination of the stream
    /// @param _role The role of the user (e.g., OPERATOR, WATCHTOWER)
    /// @return uint256 The minimum deposit required in wei
    function getMinimumDeposit(StreamDenomination _denomination, Role _role) external view returns (uint256);

    /// @notice Sets the timelock settings for a stream
    /// @dev Can only be called by the owner
    /// @param _streamId The ID of the stream
    /// @param _timelockSettings The timelock settings to set
    function setTimelockSettings(uint64 _streamId, TimelockSettings memory _timelockSettings) external;

    /// @notice Sets the security bond percentage for a specific role
    /// @param _role The role for which to set the security bond percentage
    /// @param _percentage The new security bond percentage to set
    /// @dev The percentage must be between 0 and 10000, where 10000 represents 100%
    /// @dev Only callable by the contract owner
    /// @dev Emits a SecurityBondPercentageUpdated event on success
    function setSecurityBondPercentage(Role _role, uint16 _percentage) external;

    /// @notice Sets the minimum security deposit required for the system
    /// @param _cost The new minimum security deposit in wei
    /// @dev Only callable by the contract owner
    /// @dev Emits a MinimumSecurityDepositUpdated event on success
    function setMinimumSecurityDeposit(uint256 _cost) external;

    /// @notice Sets the disablement payments cost per challenge, this is used to calculate the minimum deposit for a role
    /// @param _cost The new disablement payments per challenge in wei
    /// @dev Can only be called by the owner
    /// @dev Emits a DisablementPaymentsPerChallengeUpdated event on success
    function setDisablementPaymentsPerChallenge(uint256 _cost) external;

    /// @notice Stores the stream position for a given accept peg-in transaction ID
    /// @param _acceptPeginTxid The accept peg-in transaction ID
    /// @param _position The stream position to store
    /// @dev Only callable by the PegManager contract
    function setStreamPosition(bytes32 _acceptPeginTxid, StreamPosition memory _position) external;

    /// @notice Retrieves the stream position for a given accept peg-in transaction ID
    /// @param _acceptPeginTxid The accept peg-in transaction ID
    /// @return The stream position associated with the transaction ID
    function getStreamPosition(bytes32 _acceptPeginTxid) external view returns (StreamPosition memory);

    /// @notice Retrieves the active packets associated to a stream
    /// @param _streamId The ID of the stream
    /// @return The list of active packets IDs
    function getActivePackets(uint64 _streamId) external view returns (uint64[] memory);

    /// @notice Gets the length of the slots in a packet
    /// @param _streamId The ID of the stream
    /// @param _packetNumber The packet number
    /// @return The length of the slots in the packet
    function getPacketSlotsLength(uint64 _streamId, uint64 _packetNumber) external view returns (uint64);

    /// @notice Updates only the peg status of an existing stream position
    /// @param _acceptPeginTxid The accept peg-in transaction ID
    /// @param _newStatus The new peg status to set
    /// @dev Only callable by the PegManager contract
    function setPegStatus(bytes32 _acceptPeginTxid, PegStatus _newStatus) external;

    // Events
    /// @notice Event emitted when a new stream is created
    /// @param streamId The ID of the newly created stream
    /// @param denomination The denomination of the stream in satoshis
    event StreamCreated(uint64 streamId, uint64 denomination);

    /// @notice Event emitted when a new packet is created
    /// @param streamId The ID of the stream containing the packet
    /// @param packetNumber The number of the newly created packet
    event PacketCreated(uint64 streamId, uint64 packetNumber);

    /// @notice Event emitted when a packet is closed in the stream
    /// @param streamId The ID of the stream where the packet was closed
    /// @param packetNumber The number of the packet that was closed
    /// @dev Indicates that all slots in the packet have been processed and pegged out
    /// @dev This event is used to track the lifecycle of packets in the stream
    event PacketClosed(uint64 indexed streamId, uint64 indexed packetNumber);

    /// @notice Event emitted when a new slot is created
    /// @param streamId The ID of the stream containing the slot
    /// @param packetNumber The number of the packet containing the slot
    /// @param slotId The ID of the newly created slot
    event SlotReserved(uint64 streamId, uint64 packetNumber, uint64 slotId);

    /// @notice Event emitted when a slot is filled with accept peg-in transaction details
    /// @param streamId The ID of the stream containing the slot
    /// @param packetNumber The number of the packet containing the slot
    /// @param slotId The ID of the slot that was filled
    /// @param acceptPeginTx The hash of the accept peg-in transaction
    /// @param acceptPeginAmount The amount of the accept peg-in transaction
    event SlotFilled(
        uint64 streamId, uint64 packetNumber, uint64 slotId, bytes32 acceptPeginTx, uint64 acceptPeginAmount
    );

    /// @notice Event emitted when Security Bond Percentage is updated
    /// @param role The role for which the security bond percentage was updated
    /// @param percentage The new security bond percentage for the role
    /// @dev The percentage is represented as a value between 0 and 10000,
    /// where 10000 represents 100%
    event SecurityBondPercentageUpdated(Role role, uint16 percentage);

    /// @notice Event emitted when the minimum security deposit is updated
    /// @param cost The new minimum security deposit in wei
    event MinimumSecurityDepositUpdated(uint256 cost);

    /// @notice Event emitted when disablement payments per challenge are updated
    /// @param newCost The new disablement payments per challenge in wei
    event DisablementPaymentsPerChallengeUpdated(uint256 newCost);

    /// @notice Event emitted when a stream position is set
    /// @param acceptPeginTxid The accept peg-in transaction ID
    /// @param position The stream position that was set
    event StreamPositionSet(bytes32 indexed acceptPeginTxid, StreamPosition position);

    /// @notice Event emitted when a peg status is updated
    /// @param acceptPeginTxid The accept peg-in transaction ID
    /// @param newStatus The new peg status
    event PegStatusUpdated(bytes32 indexed acceptPeginTxid, PegStatus newStatus);

    /// @notice Event emitted when the number of confirmations required for peg-in transactions is updated
    /// @param _streamId The ID of the stream
    /// @param _confirmations The number of confirmations required
    event PeginConfirmationsUpdated(uint64 _streamId, uint8 _confirmations);

    /// @notice Event emitted when the number of confirmations required for peg-out transactions is updated
    /// @param _streamId The ID of the stream
    /// @param _confirmations The number of confirmations required
    event PegoutConfirmationsUpdated(uint64 _streamId, uint8 _confirmations);

    /// @notice Event emitted when the timelock settings are updated
    /// @param _streamId The ID of the stream
    /// @param _timelockSettings The timelock settings that were updated
    event TimelockSettingsUpdated(uint64 _streamId, TimelockSettings _timelockSettings);

    // Errors
    /// @notice Thrown when a stream is not found for the given denomination
    /// @param denomination The denomination that was not found
    error StreamNotFoundByDenomination(uint256 denomination);

    /// @notice Thrown when a stream is not found for the given stream ID
    /// @param streamId The stream ID that was not found
    error StreamNotFoundById(uint256 streamId);

    /// @notice Thrown when a packet number is out of bounds
    /// @param packetNumber The packet number that is out of bounds
    error PacketOutOfBound(uint256 packetNumber);

    /// @notice Thrown when there are no empty slots available in a packet
    /// @param streamId The stream ID
    /// @param packetNumber The packet number
    error NoEmptySlot(uint256 streamId, uint256 packetNumber);

    /// @notice Thrown when there are too many denominations
    /// @param maxDenominationsSize The maximum number of denominations allowed
    error tooManyDenominations(uint256 maxDenominationsSize);

    /// @notice Thrown when there are no filled slots available for a given stream
    /// @param streamId The stream ID
    error NoFilledSlot(uint256 streamId);

    /// @notice Thrown when there is already a pegout in process for a given stream
    /// @param streamId The stream ID
    error PegoutInProcess(uint256 streamId);

    /// @notice Thrown when a slot is in an unexpected state during lockSlot
    /// @param streamId The stream ID
    /// @param packetNumber The packet number
    /// @param slotId The slot ID
    /// @param currentState The unexpected state
    error _InconsistentSlotState(uint256 streamId, uint256 packetNumber, uint256 slotId, SlotState currentState);

    // TODO: should this error be internal?
    /// @notice Thrown when there are inconsistent slots per packet
    /// @param streamId The stream ID
    /// @param packetNumber The packet number
    /// @param slotsPerPacket The number of slots per packet
    error _InconsistentSlotsPerPacket(uint256 streamId, uint256 packetNumber, uint256 slotsPerPacket);

    /// @notice Thrown when the peg-in packet number is invalid
    /// @param streamId The stream ID
    /// @param packetNumber The invalid packet number
    error InvalidPeginPacketNumber(uint256 streamId, uint256 packetNumber);

    /// @notice Thrown when a slot does not exist
    /// @param streamId The stream ID
    /// @param packetNumber The packet number
    /// @param slotId The slot ID
    error NonExistentSlot(uint256 streamId, uint256 packetNumber, uint256 slotId);

    /// @notice Thrown when streams are already initialized
    error StreamsAlreadyInitialized();

    /// @notice Thrown when peg-in confirmations are invalid
    /// @param confirmations The invalid number of confirmations
    error InvalidPeginConfirmations(uint8 confirmations);

    /// @notice Thrown when peg-out confirmations are invalid
    /// @param confirmations The invalid number of confirmations
    error InvalidPegoutConfirmations(uint8 confirmations);

    /// @notice Thrown when the slot state doesn't match the expected state
    /// @param actual The actual slot state
    /// @param expected The expected slot state
    error InvalidSlotState(SlotState actual, SlotState expected);

    /// @notice Thrown when a percentage value is invalid
    /// @param percentage The invalid percentage value
    /// @dev The percentage must be between 0 and 10000, where 10000 represents 100%
    error InvalidPercentage(uint16 percentage);

    /// @notice Thrown when a role is invalid
    /// @param role The invalid role
    error InvalidRole(Role role);

    /// @notice Thrown when a value is zero when it shouldn't be
    error InvalidZeroValue();

    /// @notice Thrown when an address is zero address
    error InvalidZeroAddress();

    /// @notice Thrown when trying to fill a slot that's not reserved
    /// @param streamId The stream ID
    /// @param packetNumber The packet number
    /// @param slotId The slot ID
    /// @param currentState The current state of the slot
    error SlotNotReserved(uint256 streamId, uint256 packetNumber, uint256 slotId, SlotState currentState);

    /// @notice Thrown when trying to block a slot that's not reserved
    /// @param streamId The stream ID
    /// @param packetNumber The packet number
    /// @param slotId The slot ID
    /// @param currentState The current state of the slot
    error SlotNotBlockable(uint256 streamId, uint256 packetNumber, uint256 slotId, SlotState currentState);

    /// @notice Thrown when the timelock settings are invalid
    /// @param timelockSettings The invalid timelock settings
    error InvalidTimelockSettings(TimelockSettings timelockSettings);

    /// @notice Thrown when the stream settings confirmations are invalid
    /// @param streamId The stream ID
    /// @param denomination The denomination of the stream
    /// @param peginConfirmations The number of peg-in confirmations
    /// @param pegoutConfirmations The number of peg-out confirmations
    error InvalidStreamSettings(
        uint64 streamId, uint64 denomination, uint8 peginConfirmations, uint8 pegoutConfirmations
    );

    /// @notice Thrown when the stream settings length is invalid
    /// @param actualLength The number of stream settings
    /// @param expectedLength The number of stream settings
    error InvalidStreamSettingsLength(uint256 actualLength, uint256 expectedLength);

    // --- TESTNET ONLY: Force close committee functionality ---
    // TODO: Remove before mainnet deployment
    event StreamPointersRestarted(uint64 streamId);

    function restartStreamPointers_TESTNET(uint64 _streamId) external;

    function closePacket_TESTNET(uint64 _streamId, uint64 _packetNumber) external;
    // --- END TESTNET ONLY ---
}
