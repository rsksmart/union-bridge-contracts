// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {IAccessControl} from "./IAccessControl.sol";
import {ICommitteeRegistry, Role} from "./ICommitteeRegistry.sol";
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
    /// @notice The scriptPubKey of the Accept Peg-in enabler output
    /// @dev This is the locking script for the enabler output that will be consumed by the peg-out transaction
    bytes enablerScriptPubKey;
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
    /// @notice Index pointing to the current packet that should have filled slots for peg-out requests
    /// @dev Used to track which packet should be processed for peg-out operations
    uint64 pegoutPacketPointer;
    /// @notice Index pointing to the first slot in the pegoutPacketPointer that should be processed
    /// @dev Used to track which slot should be processed next for peg-out operations
    uint16 pegoutSlotPointer;
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
interface IStreamManager is IAccessControl {
    /// @notice Creates a new packet in a specific stream with committee assignment
    /// @dev Only callable by the CommitteeRegistry smart contract
    /// @param _streamId The index of the stream to add the packet to
    /// @param _committeeId The ID of the committee responsible for this packet
    /// @param _committeePubKey The public key of the selected committee for the packet (33 bytes)
    function createNewPacket(uint64 _streamId, uint128 _committeeId, bytes calldata _committeePubKey) external;

    /// @notice Retrieves stream information for a given denomination
    /// @dev Looks up the stream that handles the specified Bitcoin amount
    /// @param _denomination The value in satoshis used to identify the stream
    /// @return Stream The complete stream information
    function getStream(uint64 _denomination) external view returns (Stream calldata);

    /// @notice Retrieves stream information for a given stream ID
    /// @dev Direct lookup by stream index
    /// @param _streamId The index of the stream to retrieve
    /// @return Stream The complete stream information
    function getStreamById(uint64 _streamId) external view returns (Stream calldata);

    /// @notice Gets the total number of streams in the system
    /// @return uint64 The number of streams
    function getStreamsLength() external view returns (uint64);

    /// @notice Gets the number of packets in a specific stream
    /// @param _streamId The index of the stream
    /// @return uint64 The number of packets in the stream
    function getPacketsLength(uint64 _streamId) external view returns (uint64);

    /// @notice Retrieves packet information for a specific packet in a stream
    /// @param _streamId The index of the stream
    /// @param _packetNumber The index of the packet within the stream
    /// @return Packet The complete packet information
    function getPacket(uint64 _streamId, uint64 _packetNumber) external view returns (Packet memory);

    /// @notice Locks the first filled slot in a stream for peg-out processing
    /// @notice Reverts if a pegout is already in progress for the same stream
    /// @dev Returns the slot information and packet number for the locked slot
    /// @param _streamId The index of the stream
    /// @return slot The slot information for the locked slot
    /// @return packetNumber The packet number containing the locked slot
    function lockSlot(uint64 _streamId) external returns (Slot memory, uint64 packetNumber);

    /// @notice Retrieves slot information for a specific slot in a packet
    /// @param _streamId The index of the stream
    /// @param _packetNumber The index of the packet within the stream
    /// @param _slotNumber The index of the slot within the packet
    /// @return Slot The complete slot information
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
    /// @param _enablerScriptPubKey The scriptPubKey of the accept peg-in enabler output
    function fillSlot(
        StreamPosition memory _stream,
        uint64 _acceptPeginAmount,
        bytes32 _acceptPeginTx,
        bytes memory _scriptPubKey,
        bytes memory _enablerScriptPubKey
    ) external;

    /// @notice Blocks a reserved slot due to timeout or refund proof
    /// @dev Updates the slot state from RESERVED to BLOCKED
    /// @param _streamId The index of the stream
    /// @param _packetNumber The index of the packet within the stream
    /// @param _slotId The ID of the slot to block
    function blockSlot(uint64 _streamId, uint64 _packetNumber, uint64 _slotId) external;

    /// @notice Retrieves the committee ID for a specific packet
    /// @param _streamId The index of the stream
    /// @param _packetNumber The index of the packet within the stream
    /// @return uint256 The committee ID responsible for this packet
    function getCommitteeId(uint64 _streamId, uint64 _packetNumber) external view returns (uint128);

    /// @notice Retrieves the committee public key for a specific packet
    /// @param _streamId The index of the stream
    /// @param _packetNumber The index of the packet within the stream
    /// @return bytes The committee public key for this packet (33 bytes)
    function getCommitteePubKey(uint64 _streamId, uint64 _packetNumber) external view returns (bytes memory);

    /// @notice Marks a slot as paid and updates its state
    /// @dev Updates the slot state to COMPLETED and stores the peg-out transaction ID
    /// @param _streamId The index of the stream
    /// @param _packetNumber The index of the packet within the stream
    /// @param _slotId The index of the slot within the packet
    /// @param _acceptPeginTxid The expected accept peg-in transaction id for validation
    /// @param _userTakeTx The transaction ID of the normal peg-out transaction
    function completeSlot(
        uint64 _streamId,
        uint64 _packetNumber,
        uint64 _slotId,
        bytes32 _acceptPeginTxid,
        bytes32 _userTakeTx
    ) external;

    /// @notice Marks a slot as advanced by the operator to the user
    /// @dev Updates the slot state to ADVANCED and stores the operator's peg-out transaction
    /// @param _streamId The index of the stream
    /// @param _packetNumber The index of the packet within the stream
    /// @param _slotId The index of the slot within the packet
    function advanceSlot(uint64 _streamId, uint64 _packetNumber, uint64 _slotId) external;

    /// @notice Sets the number of confirmations required for peg-in transactions
    /// @dev Only callable by the contract owner
    /// @param _streamId The index of the stream
    /// @param _confirmations The number of confirmations required for peg-in transactions
    function setPeginConfirmations(uint64 _streamId, uint8 _confirmations) external;

    /// @notice Sets the number of confirmations required for peg-out transactions
    /// @dev Only callable by the contract owner
    /// @param _streamId The index of the stream
    /// @param _confirmations The number of confirmations required for peg-out transactions
    function setPegoutConfirmations(uint64 _streamId, uint8 _confirmations) external;

    /// @notice Gets the committee ID for the current packet in a stream
    /// @param _streamId The index of the stream
    /// @return uint256 The committee ID for the current packet (returns 0 if no current packet)
    function getAvailablePeginCommitteeId(uint64 _streamId) external view returns (uint128);

    /// @notice Gets the minimum deposit required for a specific denomination and role
    /// @param _denomination The denomination of the stream
    /// @param _role The role of the user (e.g., OPERATOR, WATCHTOWER)
    /// @return uint256 The minimum deposit required in wei
    function getMinimumDeposit(StreamDenomination _denomination, Role _role) external view returns (uint256);

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

    /// @notice Sets the disablement payments per challenge
    /// @param _cost The new disablement payments per challenge in wei
    /// @dev Only callable by the contract owner
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

    /// @notice Event emitted when the committee registry contract address  is updated
    /// @param _committeeRegistry The new committee registry contract address
    event CommitteeRegistryUpdated(ICommitteeRegistry _committeeRegistry);

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

    /// @notice Thrown when no packets are available for a given stream
    /// @param streamId The stream ID
    error NoPacketAvailable(uint256 streamId);

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

    /// @notice Thrown when a stream is already initialized
    /// @param streamId The stream ID that is already initialized
    error StreamAlreadyInitialized(uint256 streamId);

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

    /// @notice Thrown when the accept peg-in transaction id doesn't match
    /// @param expected The expected transaction id
    /// @param actual The actual transaction id
    error InvalidAcceptPeginTxid(bytes32 expected, bytes32 actual);

    /// @notice Thrown when an address is zero
    error InvalidZeroAddress();

    /// @notice Thrown when a percentage value is invalid
    /// @param percentage The invalid percentage value
    /// @dev The percentage must be between 0 and 10000, where 10000 represents 100%
    error InvalidPercentage(uint16 percentage);

    /// @notice Thrown when a role is invalid
    /// @param role The invalid role
    error InvalidRole(Role role);

    /// @notice Thrown when a value is zero when it shouldn't be
    error InvalidZeroValue();

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
    /// @param streamSettingsLength The number of stream settings
    error InvalidStreamSettingsLength(uint256 streamSettingsLength);
}
