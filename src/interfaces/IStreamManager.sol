// SPDX-License-Identifier: UNKNOWN
pragma solidity ^0.8.20;

import {IAccessControl} from "./IAccessControl.sol";

enum StreamDenomination { //TODO integrate this enum into StreamManager logic
    _0_001BTC,
    _0_01BTC,
    _0_1BTC,
    _1BTC,
    _10BTC
}

enum SlotState {
    PREPARED,
    FILLED,
    PAID,
    LOCKED
}

struct Slot {
    uint64 slotId; // Unique ID
    SlotState state; // The state of the slot
    bytes scriptPubKey; // The scriptPubKey of the Accept Peg-in Output UTXO
    bytes32 acceptPegInTx; // Transaction id of the committee peg-in transaction
    uint64 acceptPegInAmount; // The value of the accept peg-in transaction P2TR utxo
    bytes32 take0Tx; // Transaction id of the peg-out without dispute transaction
    bytes32 take1Tx; // Transaction id of the successfull dispute peg-out transaction
}

struct Packet {
    uint64 packetNumber; // Unique ID
    // uint64 denomination; // The denomination in satoshis of the packet (redundant, this field is also in the stream structure)
    // Slot[] slots; // A dynamic array to store the slots of the packet
    // Arrays should not be in scruct otherwise they are too havy on memory and cause a stack too deep exception
    // uint256 slotLength; // Length of the array (redundant but can be stored if needed)
    // uint256 committeeId; // Unique committee ID // Not Necessary
    uint256 committeeId; // The committee ID
    bytes32 committeePubKey; // The internal key of the committee
}

struct Stream {
    uint64 streamId; // Unique ID
    uint64 denomination; // The denomination of the stream in satoshis
    // Packet[] packets; // A dynamic array to store the packets of the stream
    // Arrays should not be in scruct otherwise they are too havy on memory and cause a stack too deep exception
    // uint8 packetLength; // Length of the array (redundant but can be stored if needed)
    uint64 peginPacketPointer; // An index for the packets array. It points to the current packet with space to a slot to register a peg-in request
    uint64 pegoutPacketPointer; // Another index for the packets array. It points to the current packet that should have a slot filled for a peg-out request
    uint16 pegoutSlotPointer; // An index for the slots array. It points to the first slot in the pegoutPacketPointer that should be processed when requested (if it's filled)
    uint8 peginConfirmations; // A generic number
    uint8 pegOutConfirmations; // Another generic number
    uint256 securityBondValue; // The required bond (in wei) that each member of the committee needs to deposit to secure a packet
}

interface IStreamManager is IAccessControl {
    /// @notice Adds a packet to a specific stream with the committee public key
    /// @param _streamId The index in the array of streams
    /// @param _committeeId The id of the committee for the packet
    /// @param _committeePubKey The public key of the selected committee for the packet
    function createNewPacket(uint64 _streamId, uint256 _committeeId, bytes32 _committeePubKey) external;

    /// @notice Allows users to get the Stream information for a given denomination
    /// @param _denomination The value to peg in used by the stream in satoshi
    /// @return Stream The stream information
    function getStream(uint64 _denomination) external view returns (Stream calldata);

    /// @notice Allows users to get the Stream information for a given index
    /// @param _streamId The index in the array of streams
    /// @return Stream The stream information
    function getStreamById(uint64 _streamId) external view returns (Stream calldata);

    /// @notice Get the number of streams
    /// @return uint64 The number of streams
    function getStreamsLength() external view returns (uint64);

    /// @notice Get the number of packets for a given stream
    /// @param _streamId The index in the array of streams
    function getPacketsLength(uint64 _streamId) external view returns (uint64);

    /// @notice Allows users to get the packet information for a given packet index at a stream
    /// @param _streamId The index in the array of streams
    /// @param _packetNumber The index in the array of packets
    /// @return Packet The packet information
    function getPacket(uint64 _streamId, uint64 _packetNumber) external view returns (Packet memory);

    /// @notice Allows users to get the first filled Slot information for a given packet index at a stream and lock slot
    /// @param _streamId The index in the array of streams
    /// @return slot The slot of the first filled slot information
    /// @return packetNumber The packet number of the first filled slot information
    function lockSlot(uint64 _streamId) external returns (Slot memory, uint64 packetNumber);

    /// @notice Allows users to get the Slot information for a given slot index at a packet index at a stream
    /// @param _streamId The index in the array of streams
    /// @param _packetNumber The index in the array of packets
    /// @param _slotNumber The index in the array of slots
    /// @return Slot The slot information
    function getSlot(uint64 _streamId, uint64 _packetNumber, uint64 _slotNumber) external view returns (Slot memory);

    /// @notice Allows users to fill the accept peg-in transaction for a given slot
    /// @param _streamId The index in the array of streams
    /// @param _packetNumber The index in the array of packets
    /// @param _acceptPegInAmount The amount of the accept peg-in transaction
    /// @param _acceptPegInTx The transaction id of the accept peg-in transaction
    /// @param _scriptPubKey The scriptPubKey of the accept peg-in transaction
    /// @return uint64 The slotId of the filled slot
    function fillAcceptPegInTx(
        uint64 _streamId,
        uint64 _packetNumber,
        uint64 _acceptPegInAmount,
        bytes32 _acceptPegInTx,
        bytes memory _scriptPubKey
    ) external returns (uint64);

    /// @notice Allows users to get the committee id for a given packet index at a stream
    /// @param _streamId The index in the array of streams
    /// @param _packetNumber The index in the array of packets
    /// @return uint256 The committee id
    function getCommitteeId(uint64 _streamId, uint64 _packetNumber) external view returns (uint256);

    /// @notice Allows users to get the committee public key for a given packet index at a stream
    /// @param _streamId The index in the array of streams
    /// @param _packetNumber The index in the array of packets
    /// @return bytes32 The committee public key
    function getCommitteePubKey(uint64 _streamId, uint64 _packetNumber) external view returns (bytes32);

    /// @notice Marks a slot as paid, updating its state to PAID
    /// @param _streamId The index in the array of streams
    /// @param _packetNumber The index in the array of packets
    /// @param _slotId The index in the array of slots
    /// @param _acceptPegInTxHash The expected accept peg-in transaction hash for validation
    /// @param _take0Tx The transaction id of the peg-out without dispute transaction
    function paidSlot(
        uint64 _streamId,
        uint64 _packetNumber,
        uint64 _slotId,
        bytes32 _acceptPegInTxHash,
        bytes32 _take0Tx
    ) external;

    /// @notice Allows contract owner to set the security bond value for a given stream
    /// @param _streamId The index in the array of streams
    /// @param _securityBondValue The value of the security bond expresed in RBTC in wei
    /// @dev The security bond is the amount of RBTC that each committee member needs to deposit to secure a packet
    function setSecurityBond(uint64 _streamId, uint256 _securityBondValue) external;

    /// @notice Allows contract owner to set the peg-in confirmations for a given stream
    /// @param _streamId The index in the array of streams
    /// @param _confirmations The number of confirmations required for a peg-in transaction
    /// @dev The peg-in confirmations is the number of confirmations required for a peg-in transaction to be considered valid
    function setPeginConfirmations(uint64 _streamId, uint8 _confirmations) external;

    /// @notice Allows contract owner to set the peg-out confirmations for a given stream
    /// @param _streamId The index in the array of streams
    /// @param _confirmations The number of confirmations required for a peg-out transaction
    /// @dev The peg-out confirmations is the number of confirmations required for a peg-out transaction to be considered valid
    function setPegoutConfirmations(uint64 _streamId, uint8 _confirmations) external;

    /// @notice Allows users to get the current packet committee id for a given stream
    /// @param _streamId The index in the array of streams
    /// @return uint256 The current packet committee id
    /// @dev This functions return 0 if the stream does not have a current packet (i.e. no packets created yet or last packet run out of slots)
    function getCurrentPacketCommitteeId(uint64 _streamId) external view returns (uint256);

    event StreamCreated(uint64 streamId, uint64 denomination);
    event PacketCreated(uint64 streamId, uint64 packetNumber);
    event SlotCreated(uint64 streamId, uint64 packetNumber, uint64 slotId);

    error StreamNotFoundByDenomination(uint256 denomination);
    error StreamNotFoundById(uint256 streamId);
    error PacketOutOfBound(uint256 packetNumber);
    error NoEmptySlot(uint256 streamId, uint256 packetNumber);
    error tooManyDenominations(uint256 maxDenominationsSize);
    error NoFilledSlot(uint256 streamId, uint256 packetNumber, uint256 slotId);
    error PacketNotFound(uint256 streamId, uint256 packetNumber);
    error InconsistentPegoutPointer(uint256 streamId, uint256 packetNumber, uint256 slotPointer);
    error InconsistentSlotsPerPacket(uint256 streamId, uint256 packetNumber, uint256 slotsPerPacket);
    error InvalidPeginPacketNumber(uint256 streamId, uint256 packetNumber);
    error NonExistentSlot(uint256 streamId, uint256 packetNumber, uint256 slotId);
    error StreamAlreadyInitialized(uint256 streamId);
    error InvalidPeginConfirmations(uint8 confirmations);
    error InvalidPegoutConfirmations(uint8 confirmations);
    error InvalidSecurityBondValue(uint256 securityBond);
    error InvalidSlotState(SlotState actual, SlotState expected);
    error InvalidAcceptPegInTxHash(bytes32 expected, bytes32 actual);
    error InvalidZeroAddress();
}
