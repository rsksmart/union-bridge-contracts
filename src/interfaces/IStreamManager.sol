// SPDX-License-Identifier: UNKNOWN
pragma solidity ^0.8.20;

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
    // TBD drp;                        // Dispute Resolution Protocol information
    // TBD otk;                        // Dispute Resolution Protocol one-time-keys
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
    bytes32 committeePubKey; // The internal key of the committee
}

struct Stream {
    uint64 streamId; // Unique ID
    uint64 denomination; // The denomination of the stream in satoshis
    // Packet[] packets; // A dynamic array to store the packets of the stream
    // Arrays should not be in scruct otherwise they are too havy on memory and cause a stack too deep exception
    // uint8 packetLength; // Length of the array (redundant but can be stored if needed)
    uint8 peginPointer; // An index for the packets array. It points to the next available slot to register a peg-in request
    int8 pegoutPointer; // Another index for the packets array. It points to the first peg-out that will be processed when requested
    uint8 pegInConfirmations; // A generic number
    //uint8 pegOutConfirmations; // Another generic number
    uint64 securityBondValue; // The required bond (in satoshis) that each member of the committee needs to deposit to secure a packet
}

interface IStreamManager {
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

    /// @notice Allows users to get the Packet information for a given packet index at a stream
    /// @param _streamId The index in the array of streams
    /// @param _packetNumber The index in the array of packets
    /// @return Packet The packet information
    function getPacket(uint64 _streamId, uint64 _packetNumber) external view returns (Packet calldata);

    /// @notice Allows users to get the first prepared Slot information for a given packet index at a stream
    /// @param _streamId The index in the array of streams
    /// @param _packetNumber The index in the array of packets
    /// @return uint256 The slotId of the first prepared slot information
    function getPreparedSlotId(uint64 _streamId, uint64 _packetNumber) external view returns (uint64);

    // /// @notice Allows users to get the first filled Slot information for a given packet index at a stream
    // /// @param _streamId The index in the array of streams
    // /// @param _packetNumber The index in the array of packets
    // /// @return uint256 The slotId of the first filled slot information
    // function getFilledSlotId(uint64 _streamId, uint64 _packetNumber) external view returns (uint64);

    // /// @notice Allows users to get the next available packet for a stream
    // /// @param _streamId The index in the array of streams
    // /// @return Packet The packet information
    // function getNextAvailablePacket(uint64 _streamId) external view returns (Packet memory);

    /// @notice Allows users to get the Slot information for a given slot index at a packet index at a stream
    /// @param _streamId The index in the array of streams
    /// @param _packetNumber The index in the array of packets
    /// @param _slotNumber The index in the array of slots
    /// @return Slot The slot information
    function getSlot(uint64 _streamId, uint64 _packetNumber, uint64 _slotNumber) external view returns (Slot memory);

    function createPacketsAndSlots(bytes32 _committeePubKey) external;

    error StreamNotFoundByDenomination(uint256 denomination);
    error PacketOutOfBound(uint256 packetNumber);
    error NoEmptySlot(uint256 streamId, uint256 packetNumber);
    error tooManyDenominations(uint256 maxDenominationsSize);
    error NoFilledSlot(uint256 streamId, uint256 packetNumber);
    error NonExistentSlot(uint256 streamId, uint256 packetNumber, uint256 slotId);
}
