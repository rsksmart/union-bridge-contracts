// SPDX-License-Identifier: UNKNOWN
pragma solidity ^0.8.20;

struct BtcTransaction {
    bytes4 version; // TX version: 02000000
    bytes2 witnessMarkerFlag; // Witness marker and flag: 0001
    uint8 inputCount; // Input count: 01
    bytes[] inputs; // hex inputs
    uint8 scriptSigLen; // Unlocking script length: 00
    bytes[] scriptSig; // Unlocking script: EMPTY (note: non-SegWit inputs will have script length >0 and have the unlocking script here instead of in the witness, so for non-SegWit this will not be EMPTY)
    uint32 sequence; // "sequence": 4294967293
    uint8 outputCount; // Output count: 02
    bytes[] outputs; // All outputs Output 01: 40420f00000000001976a914341b568f59229818c460b1795ad48cd78895c54d88ac Output 02: 6eeefa4a00000000160014d701ce5e753bd9454d343c8a3b86d84a3c34dbf5
    uint8 witnessCount; // TWitness count: 02
    bytes[] witness; // All witness  Witness 01: 473044022001609cd43eb8e9b8f8438eded9f6b10bad32efd7620724ccd2ed5277c0c6a3ae02200f0c1c3f4c409ada536d2363a2d8bdad418df67fed9b36bfa4482bd9985bf39601 Witness 02: 2102ee3c98964dd1bfe13bee16c0b95fcf8281f12c5885d1fcb7b59fc2cb01ca7632
    uint64 locktime; // TX locktime: 00000000
}

struct PegInRequestTxSPVProof {
    uint256 packetNumber; // Packet Index in the Stream
    address destinationAddress; // destination Address in Rootstock
    string btcReinburstmentAddress; // Bitcoin reimburstment address
    uint64 value; // The denomination of the stream in satoshis
    bytes32 blockHash; // The Bitcoin Block Hash where the pegin tx happened
    string utxo; // UTXO of the PegIn Transaction
    bytes rawTx; // The Bitcoin PegIn Transaction Hash
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
