// SPDX-License-Identifier: UNKNOWN
pragma solidity ^0.8.20;

import {BtcTransaction} from "./IBitcoinManager.sol";
import {IStreamManager} from "./IStreamManager.sol";

struct PegInRequestTxSPVProof {
    bytes32 blockHash; // The Bitcoin Block Hash where the request pegin tx happened
    BtcTransaction btcTx; // The Bitcoin Request PegIn Transaction
    // Merkle Path is a uint but is actually an array of bits
    // indicating if the path is left of right according to 1 or 0
    uint256 merkleBranchPath;
    // Merkle Branch Hashes are the hashes that will be used together with the merkleBranchPath
    // to obtain the Merkle Root, this is an optimization to avoid sending the whole Merkle Tree
    bytes32[] merkleBranchHashes;
}

struct PegInAcceptedTxSPVProof {
    bytes32 blockHash; // The Bitcoin Block Hash where the accept pegin tx happened
    BtcTransaction btcTx; // The Bitcoin Accept PegIn Transaction
        // Merkle Path is a uint but is actually an array of bits
    // indicating if the path is left of right according to 1 or 0
    uint256 merkleBranchPath;
    // Merkle Branch Hashes are the hashes that will be used together with the merkleBranchPath
    // to obtain the Merkle Root, this is an optimization to avoid sending the whole Merkle Tree
    bytes32[] merkleBranchHashes;
}

struct StreamPosition {
    uint64 streamId;
    uint64 packetNumber;
    bool registered;
}

struct PegInTempInfo {
    uint64 value;
    address destinationAddress;
    bytes32 btcReimbursementPubKey;
    bytes utxoScriptPubKey;
}

interface IPegManager is IStreamManager {
    /// @notice Allows users generate a temporary Bitcoin address to perform a peg-in.
    /// @param _rootstockDepositAddress The RSK deposit address
    /// @param _btcReimbursementPubKey The BTC reimbursement public key (x only)
    /// @param _value The amount to peg in
    /// @return temporaryPegInAddress The temporary peg-in address
    function getTemporaryPegInAddress(address _rootstockDepositAddress, bytes32 _btcReimbursementPubKey, uint64 _value)
        external
        returns (bytes calldata temporaryPegInAddress);

    function getPegInRequest(bytes32 btcTxHash) external returns (StreamPosition calldata);

    /// @notice Register a peg-in request transaction from Bitcoin
    /// @param _pegInRequestTxSPVProof The ProofValidator proof of the peg-in request transaction
    function registerPegInRequest(PegInRequestTxSPVProof calldata _pegInRequestTxSPVProof) external;

    function getPegInTempInfo(bytes32 btcTxHash) external returns (PegInTempInfo calldata);

    /// @notice Accepts and Registers a peg in transaction out of the temporary address
    /// @param _pegInAcceptedTxSPVProof Accept peg-in transaction
    function acceptPegInRequest(PegInAcceptedTxSPVProof calldata _pegInAcceptedTxSPVProof) external;

    // /// @notice Selects UTXOs for peg-out
    // /// @param streamId The stream identifier
    // /// @param sequenceNumber The sequence number
    // /// @param slotId The slot identifier
    // function selectUTXOsForPegOut(uint256 streamId, uint256 sequenceNumber, uint256 slotId) external;

    event RegisteredPegInRequest(
        bytes32 indexed blockHash,
        bytes32 indexed txHash,
        uint64 vout,
        uint64 value,
        uint256 packetNumber,
        address destinationAddress,
        bytes32 btcReimbursementPubKey,
        bytes utxoScriptPubKey
    );

    error AlreadyRegisteredPegIn(bytes32 btcTxHash);
}
