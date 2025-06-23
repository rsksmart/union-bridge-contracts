// SPDX-License-Identifier: UNKNOWN
pragma solidity ^0.8.20;

import {BtcTransaction} from "./IBitcoinManager.sol";
import {IStreamManager, SlotState} from "./IStreamManager.sol";
import {ISignatureManager} from "./ISignatureManager.sol";

struct BtcTxSPVProof {
    bytes32 blockHash; // The Bitcoin Block Hash where the tx happened
    BtcTransaction btcTx; // The Bitcoin Transaction
    // Merkle Path is a uint but is actually an array of bits
    // indicating if the path is left of right according to 1 or 0
    uint256 merkleBranchPath;
    // Merkle Branch Hashes are the hashes that will be used together with the merkleBranchPath
    // to obtain the Merkle Root, this is an optimization to avoid sending the whole Merkle Tree
    bytes32[] merkleBranchHashes;
}

enum PegStatus {
    NOT_REGISTERED,
    REGISTERED,
    ACCEPTED,
    PAID
}
// USER_TAKEN, // User take: Key spend (everybody signs)
// TAKE_0, // Undispute advancement of funds
// TAKE_1, // Take Signal
// TAKE_2 // Disputed peg-out (Kick Off BitVMX)

struct StreamPosition {
    uint64 streamId;
    uint64 packetNumber;
    uint64 slotId;
    PegStatus pegStatus;
}

struct RequestPeginTempInfo {
    address rskDestinationAddress;
    bytes32 btcReimbursementPubKey;
    bytes32 acceptPeginSignatureHash;
}

struct PegoutTempInfo {
    bytes userPubKey;
}

interface IPegManager {
    function setStreamManager(IStreamManager _streamManager) external;
    function setSignatureManager(ISignatureManager _signatureManager) external;
    // ===================== Peg-in Request=====================

    /// @notice Allows users generate a temporary Bitcoin address to perform a peg-in.
    /// @param _rootstockDepositAddress The RSK deposit address
    /// @param _value The amount to peg in
    /// @param _btcReimbursementPubKey The BTC reimbursement public key (x only)
    /// @return temporaryPeginAddress The temporary peg-in address
    function getTemporaryPeginAddress(address _rootstockDepositAddress, uint64 _value, bytes32 _btcReimbursementPubKey)
        external
        returns (string memory temporaryPeginAddress);

    function getStreamPosition(bytes32 btcTxHash) external view returns (StreamPosition memory);

    /// @notice Register a peg-in request transaction from Bitcoin
    /// @param _peginRequestTxSPVProof The BTC SPV proof of Request the peg-in transaction
    function requestPegin(BtcTxSPVProof calldata _peginRequestTxSPVProof) external;

    event PeginRequested(
        bytes32 indexed blockHash,
        bytes32 indexed txHash,
        uint64 vout,
        uint64 value,
        uint256 packetNumber,
        address rskDestinationAddress,
        bytes32 btcReimbursementPubKey,
        bytes utxoScriptPubKey
    );

    event InitAcceptPegin(
        bytes32 indexed committeePubKey,
        bytes32 indexed requestPeginTxHash,
        bytes32 indexed acceptPeginTxHash,
        bytes32 acceptPeginSignatureHash,
        bytes acceptPeginSignatureMessage
    );

    function getPeginRequest(bytes32 _btcTxHash) external view returns (bytes32);

    function getRequestPeginTempInfo(bytes32 btcTxHash) external view returns (RequestPeginTempInfo memory);

    // ===================== Accept Peg-in Request =====================
    /// @notice Accepts and Registers a bitcoin peg in transaction out of the temporary address
    /// @param _peginAcceptedTxSPVProof The BTC SPV proof of the Accept peg-in transaction
    function acceptPegin(BtcTxSPVProof calldata _peginAcceptedTxSPVProof) external;

    event PeginAccepted(
        bytes32 indexed blockHash,
        bytes32 indexed txHash,
        bytes32 indexed peginTxHash,
        uint64 vout,
        StreamPosition streamPosition,
        bytes32 speedUpPubKey,
        address rskDestinationAddress,
        uint256 rbtcAmount,
        bytes utxoScriptPubKey
    );

    // ===================== Peg-out Request =====================
    // /// @notice Try a peg-out to Bitcoin. It will revert if not filled slot is available.
    // /// @param _usrPubKey The user public key
    function tryPegout(bytes calldata _usrPubKey) external payable;

    /// @notice Register a peg-out transaction from Bitcoin
    /// @param _pegoutTxSPVProof The BTC SPV proof of the peg-out transaction
    function registerPegout(BtcTxSPVProof calldata _pegoutTxSPVProof) external;

    // address indexed bitcoinUserAddress,
    event PegoutRequested(
        bytes indexed usrPubKey,
        uint256 indexed committeeId,
        bytes32 indexed pegoutSignatureHash,
        bytes pegoutSignatureMessage,
        uint64 streamId,
        uint64 packetNumber,
        uint64 slotId,
        uint64 amount
    );

    event PegoutRegistered(
        bytes32 indexed blockHash,
        bytes32 indexed txHash,
        bytes32 indexed acceptPeginTxHash,
        uint64 streamId,
        uint64 packetNumber,
        uint64 slotId
    );

    // ===================== Errors =====================
    error BitcoinManagerAddressZero();
    error CommitteeRegistryAddressZero();
    error SignatureManagerAddressZero();
    error StreamManagerAddressZero();
    error PegoutRequestAmountExceedsUint64Limit(uint256 amount);
    error PeginAlreadyRequested(bytes32 btcTxHash);
    error PeginNotRequested(bytes32 btcTxHash);
    error InvalidAcceptPeginTxHash(bytes32 expected, bytes32 actual);
    error PeginAlreadyAccepted(bytes32 btcTxHash);
    error IncorrectInputsNumber(uint256 actual, uint256 expected);
    error IncorrectOutputsNumber(uint256 actual, uint256 expected);
    error InvalidCompressedPubKey(bytes usrPubKey);
    error InvalidLocktime(uint256 actual, uint256 expected);
    error InvalidBtcTxVersion(uint256 actual, uint256 expected);
    error InvalidSlotState(SlotState actual, SlotState expected);
    error IncorrectVout(uint32 actual, uint32 expected);
    error IncorrectOutputScript(bytes actual, bytes expected);
}
