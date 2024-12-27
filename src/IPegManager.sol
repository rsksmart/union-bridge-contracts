// SPDX-License-Identifier: UNKNOWN
pragma solidity ^0.8.19;

interface IPegManager {
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
        Slot[] slots; // A dynamic array to store the slots of the packet
        // uint256 slotLength; // Length of the array (redundant but can be stored if needed)
        uint256 committeeId; // Unique committee ID
        bytes32 committeeInternalKey; // The internal key of the committee
    }

    struct Stream {
        uint256 streamId; // Unique ID
        uint64 denomination; // The denomination of the stream in satoshis
        Packet[] packets; // A dynamic array to store the packets of the stream
        // uint8 packetLength; // Length of the array (redundant but can be stored if needed)
        uint8 peginPointer; // An index for the packets array. It points to the next available slot to register a peg-in request
        int8 pegoutPointer; // Another index for the packets array. It points to the first peg-out that will be processed when requested
        // uint8 peginConfirmations; // A generic number
        // uint8 pegoutConfirmations; // Another generic number
        uint64 securityBondValue; // The required bond (in satoshis) that each member of the committee needs to deposit to secure a packet
    }

    /// @notice Allows users generate a temporary Bitcoin address to perform a peg-in.
    /// @param rootstockDepositAddress The RSK deposit address
    // /// @param bitcoinReimbursementAddress The BTC reimbursement address
    /// @param value The amount to peg in
    /// @return temporaryPegInAddress The temporary peg-in address
    function getTemporaryPegInAddress(
        bytes calldata rootstockDepositAddress,
        // bytes calldata bitcoinReimbursementAddress,
        uint64 value
    ) external returns (bytes memory temporaryPegInAddress);

    // /// @notice Accepts a peg-in request
    // /// @param pegInRequestTxSPVProof The SPV proof of the peg-in request transaction
    // /// @param numberOfConfirmations Number of confirmations required
    // function acceptPegInRequest(bytes calldata pegInRequestTxSPVProof, uint8 numberOfConfirmations) external;

    // /// @notice Registers peg transactions
    // /// @param take0Tx First take transaction
    // /// @param take1Tx Second take transaction
    // /// @param acceptPegInTx Accept peg-in transaction
    // /// @param take0AggregatedSignatures Signatures for take0Tx
    // /// @param take1AggregatedSignatures Signatures for take1Tx
    // /// @param acceptPegInAggregatedSignatures Signatures for acceptPegInTx
    // function registerPegTransactions(
    //     bytes calldata take0Tx,
    //     bytes calldata take1Tx,
    //     bytes calldata acceptPegInTx,
    //     bytes calldata take0AggregatedSignatures,
    //     bytes calldata take1AggregatedSignatures,
    //     bytes calldata acceptPegInAggregatedSignatures
    // ) external;

    // /// @notice Selects UTXOs for peg-out
    // /// @param streamId The stream identifier
    // /// @param sequenceNumber The sequence number
    // /// @param slotId The slot identifier
    // function selectUTXOsForPegOut(uint256 streamId, uint256 sequenceNumber, uint256 slotId) external;
}
