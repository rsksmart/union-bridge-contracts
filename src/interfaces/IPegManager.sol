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
    address rskDestinationAddress;
    bytes32 btcReimbursementPubKey;
    bytes utxoScriptPubKey;
}

struct PrevoutData {
    bytes32 txid;
    uint32 vout;
    uint64 value;
    bytes scriptPubKey;
}

interface IPegManager is IStreamManager {
    /// @notice Allows users generate a temporary Bitcoin address to perform a peg-in.
    /// @param _rootstockDepositAddress The RSK deposit address
    /// @param _value The amount to peg in
    /// @param _btcReimbursementPubKey The BTC reimbursement public key (x only)
    /// @return temporaryPegInAddress The temporary peg-in address
    function getTemporaryPegInAddress(address _rootstockDepositAddress, uint64 _value, bytes32 _btcReimbursementPubKey)
        external
        returns (string memory temporaryPegInAddress);

    function getPegInRequest(bytes32 btcTxHash) external view returns (StreamPosition calldata);

    /// @notice Register a peg-in request transaction from Bitcoin
    /// @param _pegInRequestTxSPVProof The ProofValidator proof of the peg-in request transaction
    function registerPegInRequest(PegInRequestTxSPVProof calldata _pegInRequestTxSPVProof) external;

    function getPegInTempInfo(bytes32 btcTxHash) external view returns (PegInTempInfo calldata);

    // /// @notice Verifys and Registers the partial signature for accept peg-in transaction
    // /// @param _pegInAcceptedTxSPVProof Accept peg-in transaction
    // function verifyAcceptPegInRequest(PegInAcceptedTxSPVProof calldata _pegInAcceptedTxSPVProof) external;

    /// @notice Accepts and Registers a bitcoin peg in transaction out of the temporary address
    /// @param _pegInAcceptedTxSPVProof Accept peg-in transaction
    function acceptPegInRequest(PegInAcceptedTxSPVProof calldata _pegInAcceptedTxSPVProof) external;

    // /// @notice Selects UTXOs for peg-out
    // /// @param streamId The stream identifier
    // /// @param sequenceNumber The sequence number
    // /// @param slotId The slot identifier
    // function selectUTXOsForPegOut(uint256 streamId, uint256 sequenceNumber, uint256 slotId) external;

    // /// @notice Requests a peg-out to Bitcoin
    // /// @param _usrPubKey The user public key
    // /// @param _bitcoinUserAddress The Bitcoin user address
    // /// @param _batchFlag The batch flag to indicate if the peg-out is part of a batch
    function requestPegOut(bytes calldata _usrPubKey, address _bitcoinUserAddress, bool _batchFlag) external payable;

    event RegisteredPegInRequest(
        bytes32 indexed blockHash,
        bytes32 indexed txHash,
        uint64 vout,
        uint64 value,
        uint256 packetNumber,
        address rskDestinationAddress,
        bytes32 btcReimbursementPubKey,
        bytes utxoScriptPubKey
    );

    event PegOutRequested(
        address indexed bitcoinUserAddress,
        uint64 amount,
        bytes32 indexed pegOutTxHash,
        uint64 streamId,
        uint64 packetNumber,
        uint64 slotId,
        bool batchFlag
    );

    error AlreadyRegisteredPegIn(bytes32 btcTxHash);
    error InvalidPubKeyLength(uint256 usrPubKeyLength);
}
