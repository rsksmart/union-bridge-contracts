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
    bytes32 acceptPeginTxHash;
}

struct PegOutTempInfo {
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
    function registerPeginRequest(BtcTxSPVProof calldata _peginRequestTxSPVProof) external;

    event RegisteredPeginRequest(
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
        bytes32 acceptPeginSignatureHash,
        bytes acceptPeginSignatureMessage
    );

    function getRequestPeginTempInfo(bytes32 btcTxHash) external view returns (RequestPeginTempInfo memory);

    // ===================== Accept Peg-in Request =====================

    // /// @notice Verifys and Registers the partial signature for accept peg-in transaction
    // /// @param _peginAcceptedTxSPVProof Accept peg-in transaction
    // function verifyAcceptPeginRequest(BtcTxSPVProof calldata _peginAcceptedTxSPVProof) external;

    /// @notice Accepts and Registers a bitcoin peg in transaction out of the temporary address
    /// @param _peginAcceptedTxSPVProof The BTC SPV proof of the Accept peg-in transaction
    function acceptPeginRequest(BtcTxSPVProof calldata _peginAcceptedTxSPVProof) external;

    event AcceptedPeginRequest(
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

    // /// @notice Selects UTXOs for peg-out
    // /// @param streamId The stream identifier
    // /// @param sequenceNumber The sequence number
    // /// @param slotId The slot identifier
    // function selectUTXOsForPegOut(uint256 streamId, uint256 sequenceNumber, uint256 slotId) external;

    // /// @notice Requests a peg-out to Bitcoin
    // /// @param _usrPubKey The user public key
    // /// @param _bitcoinUserAddress The Bitcoin user address
    function requestPegOut(bytes calldata _usrPubKey) external payable;

    /// @notice Register a peg-out transaction from Bitcoin
    /// @param _pegOutTxSPVProof The BTC SPV proof of the peg-out transaction
    function registerPegout(BtcTxSPVProof calldata _pegOutTxSPVProof) external;

    // address indexed bitcoinUserAddress,
    event PegOutRequested(
        bytes indexed usrPubKey,
        uint64 amount,
        bytes32 indexed pegOutSignatureHash,
        bytes commonSignatureMessage,
        uint64 streamId,
        uint64 packetNumber,
        uint64 slotId
    );

    event PegOutRegistered(
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
    error AlreadyRegisteredPegin(bytes32 btcTxHash);
    error AlreadyRegisteredPeginRequest(bytes32 btcTxHash);
    error UnregisteredPeginRequest(bytes32 btcTxHash);
    error InvalidAcceptPeginTxHash(bytes32 expected, bytes32 actual);
    error AlreadyRegisteredAcceptPegin(bytes32 btcTxHash);
    error IncorrectInputsNumber(uint256 actual, uint256 expected);
    error IncorrectOutputsNumber(uint256 actual, uint256 expected);
    error InvalidPubKeyLength(uint256 usrPubKeyLength);
    error InvalidLocktime(uint256 actual, uint256 expected);
    error InvalidBtcTxVersion(uint256 actual, uint256 expected);
    error InvalidSlotState(SlotState actual, SlotState expected);
    error IncorrectVout(uint32 actual, uint32 expected);
    error IncorrectOutputScript(bytes actual, bytes expected);
}
