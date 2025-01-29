// SPDX-License-Identifier: UNKNOWN
pragma solidity ^0.8.20;

import {BtcTransaction} from "./IBitcoinManager.sol";

struct PegInRequestTxSPVProof {
    bytes32 blockHash; // The Bitcoin Block Hash where the pegin tx happened
    string utxo; // UTXO of the PegIn Transaction
    BtcTransaction btcTx; // The Bitcoin PegIn Transaction
    uint256 merkleBranchPath; // Merkle Path is a uint but is actually an array of bits indicating if the path is left of right according to 1 or 0
    bytes32[] merkleBranchHashes; // Merkle Branch Hashes are the hashes that will be used together with the merkleBranchPath to obtain the Merkle Root, this is an optimization to avoid sending the whole Merkle Tree
}

interface IPegManager {
    /// @notice Allows users generate a temporary Bitcoin address to perform a peg-in.
    /// @param _rootstockDepositAddress The RSK deposit address
    /// @param _btcReimbursementPubKey The BTC reimbursement public key (x only)
    /// @param _value The amount to peg in
    /// @return temporaryPegInAddress The temporary peg-in address
    function getTemporaryPegInAddress(address _rootstockDepositAddress, bytes32 _btcReimbursementPubKey, uint64 _value)
        external
        returns (bytes calldata temporaryPegInAddress);

    /// @notice Accepts a peg-in request
    /// @param _pegInRequestTxSPVProof The ProofValidator proof of the peg-in request transaction
    function acceptPegInRequest(PegInRequestTxSPVProof calldata _pegInRequestTxSPVProof) external;

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
        bytes32 btcReimbursementPubKey,
        string utxo
    );
}
