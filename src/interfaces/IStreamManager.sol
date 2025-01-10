// SPDX-License-Identifier: UNKNOWN
pragma solidity ^0.8.20;

enum SlotState {
    EMPTY,
    PREPARED,
    FILLED,
    PAID
}

struct Slot {
    uint256 slotId; // Unique ID
    SlotState state; // The denomination in satoshis of the packet (redundant, this field is also in the stream structure)
    // TBD drp;                        // Dispute Resolution Protocol information
    // TBD otk;                        // Dispute Resolution Protocol one-time-keys
    string utxo; // Peg-in UTXO
    bytes peginTx; // Transaction id of the committee peg-in transaction
    bytes take0Tx; // Transaction id of the peg-out without dispute transaction
    bytes take1TX; // Transaction id of the successfull dispute peg-out transaction
}

struct Packet {
    uint256 sequenceNumber; // Unique ID
    // uint64 denomination; // The denomination in satoshis of the packet (redundant, this field is also in the stream structure)
    // Slot[] slots; // A dynamic array to store the slots of the packet
    // Arrays should not be in scruct otherwise they are too havy on memory and cause a stack too deep exception
    // uint256 slotLength; // Length of the array (redundant but can be stored if needed)
    uint256 committeeId; // Unique committee ID
    bytes32 committeeInternalKey; // The internal key of the committee
}

struct Stream {
    uint256 streamId; // Unique ID
    uint64 denomination; // The denomination of the stream in satoshis
    // Packet[] packets; // A dynamic array to store the packets of the stream
    // Arrays should not be in scruct otherwise they are too havy on memory and cause a stack too deep exception
    // uint8 packetLength; // Length of the array (redundant but can be stored if needed)
    uint8 peginPointer; // An index for the packets array. It points to the next available slot to register a peg-in request
    int8 pegoutPointer; // Another index for the packets array. It points to the first peg-out that will be processed when requested
    // uint8 peginConfirmations; // A generic number
    // uint8 pegoutConfirmations; // Another generic number
    uint64 securityBondValue; // The required bond (in satoshis) that each member of the committee needs to deposit to secure a packet
}

interface IStreamManager {
    /// @notice Allows users to get the Stream information for a given denomination
    /// @param _denomination The value to peg in used by the stream in satoshi
    /// @return Stream The stream information
    function getStream(uint64 _denomination) external view returns (Stream memory);

    /// @notice Allows users to get the Stream information for a given index
    /// @param _streamId The index in the array of streams
    /// @return Stream The stream information
    function getStreamById(uint256 _streamId) external view returns (Stream memory);

    /// @notice Get the number of streams
    /// @return uint256 The number of streams
    function getStreamsLength() external view returns (uint256);
}
