// SPDX-License-Identifier: UNKNOWN
pragma solidity ^0.8.20;

struct PegInRequestTxSPVProof {
    uint256 packetNumber; // Packet Index in the Stream
    address destinationAddress; // destination Address in Rootstock
    string btcReinburstmentAddress; // Bitcoin reimburstment address
    uint64 value; // The denomination of the stream in satoshis
    bytes32 blockHash; // The Bitcoin Block Hash where the pegin tx happened
    string utxo; // UTXO of the PegIn Transaction
    bytes32 txHash; // The Bitcoin PegIn Transaction Hash
    uint256 merkleBranchPath; // Merkle Path is a uint but is actually an array of bits indicating if the path is left of right according to 1 or 0
    bytes32[] merkleBranchHashes; // Merkle Branch Hashes are the hashes that will be used together with the merkleBranchPath to obtain the Merkle Root, this is an optimization to avoid sending the whole Merkle Tree
}

interface IPegManager {
    /// @notice Allows users generate a temporary Bitcoin address to perform a peg-in.
    /// @param _rootstockDepositAddress The RSK deposit address
    // /// @param bitcoinReimbursementAddress The BTC reimbursement address
    /// @param _value The amount to peg in
    /// @return temporaryPegInAddress The temporary peg-in address
    function getTemporaryPegInAddress(
        bytes calldata _rootstockDepositAddress,
        // bytes calldata bitcoinReimbursementAddress,
        uint64 _value
    ) external returns (bytes calldata temporaryPegInAddress);

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

    event PrepareTakeTransaction(
        bytes32 indexed blockHash,
        bytes32 indexed txHash,
        uint64 value,
        uint256 packetNumber,
        uint256 slotId,
        address destinationAddress,
        string btcReinburstmentAddress,
        string utxo
    );

    error bridgeBtcInexistantBlockHash(bytes32 blockHash);
    error bridgeBtcBlockNotInBestChain(bytes32 blockHash);
    error bridgeBtcInconsistentBlock(bytes32 blockHash);
    error bridgeBtcBlockTooOld(int256 maxDepth);
    error bridgeBtcTxInvalidMerkleBranch(uint256 merkleBranchPath, bytes32[] merkleBranchHashes);
    error bridgeBtcUnknownError(int256 errorCode);
    error notEnoughConfirmations(int256 actual, uint256 expected);
}
