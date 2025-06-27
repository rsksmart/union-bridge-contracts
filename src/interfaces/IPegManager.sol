// SPDX-License-Identifier: UNKNOWN
pragma solidity ^0.8.20;

import {BtcTransaction, PrevoutData} from "./IBitcoinManager.sol";
import {IStreamManager, SlotState} from "./IStreamManager.sol";
import {ISignatureManager} from "./ISignatureManager.sol";

/// @notice Represents a Bitcoin transaction with SPV proof for bridge validation
/// @dev Contains the transaction data along with merkle proof for block inclusion verification
/// @dev Used to prove that a Bitcoin transaction is included in a specific block without full node verification
struct BtcTxSPVProof {
    /// @notice The Bitcoin block hash where the transaction was included
    /// @dev Used to verify the block exists and has sufficient confirmations
    bytes32 blockHash;
    /// @notice The Bitcoin transaction data
    /// @dev Contains all transaction details needed for transaction hash calculation
    BtcTransaction btcTx;
    /// @notice Merkle path indicating left/right traversal in the merkle tree
    /// @dev Each bit represents whether to go left (0) or right (1) in the merkle tree
    /// @dev This is an optimization to avoid sending the complete merkle tree
    uint256 merkleBranchPath;
    /// @notice Array of merkle branch hashes for proof verification
    /// @dev These hashes are used together with the merkleBranchPath to reconstruct the merkle root
    /// @dev Allows verification of transaction inclusion without full merkle tree
    bytes32[] merkleBranchHashes;
}

/// @notice Represents the current status of a peg-in or peg-out operation
/// @dev Tracks the progression of funds through the bridge system
enum PegStatus {
    /// @notice Operation has not been registered yet
    NOT_REGISTERED,
    /// @notice Operation has been registered and is awaiting committee acceptance
    REGISTERED,
    /// @notice Operation has been accepted by the committee and funds are in the committee account
    ACCEPTED,
    /// @notice Operation has been taken by the user and is awaiting committee acceptance
    USER_TAKE,
    /// @notice Operation has been taken by the operator and is awaiting committee acceptance
    OPERATOR_TAKE,
    /// @notice Operation has been won by the operator and is awaiting committee acceptance
    OPERATOR_WON,
    /// @notice Operation has been completed and funds have been paid out
    PAID
}

/// @notice Represents the position of funds within the stream and packet system
/// @dev Tracks where funds are located in the hierarchical stream/packet/slot structure
struct StreamPosition {
    /// @notice The stream ID where the funds are located
    uint64 streamId;
    /// @notice The packet number within the stream
    uint64 packetNumber;
    /// @notice The slot ID within the packet
    uint64 slotId;
    /// @notice The current status of the peg operation
    PegStatus pegStatus;
}

/// @notice Temporary information stored during peg-in request processing
/// @dev Contains data needed for the accept peg-in phase
struct RequestPeginTempInfo {
    /// @notice The RSK address that will receive the RBTC
    address rskDestinationAddress;
    /// @notice The user's Bitcoin public key for reimbursement (x-coordinate only)
    bytes32 btcReimbursementPubKey;
    /// @notice The signature hash that committee members need to sign
    bytes32 acceptPeginSignatureHash;
}

/// @notice Temporary information stored during peg-out processing
/// @dev Contains data needed for peg-out transaction validation
struct PegoutTempInfo {
    /// @notice The user's public key that will receive the Bitcoin funds
    bytes userPubKey;
    uint256 createdAt;
    uint256 operatorTakeUpdatedAt;
    address takeOperator; // The operator that will do the advancement of funds
    uint256 committeeId;
}

/// @notice Interface for managing peg-in and peg-out operations in the union bridge
/// @dev This interface provides functions for processing Bitcoin to RSK and RSK to Bitcoin transfers
/// @dev Handles the complete lifecycle of peg operations including request, acceptance, and completion
interface IPegManager {
    /// @notice Sets the stream manager contract address
    /// @dev Only callable by the contract owner
    /// @param _streamManager The address of the stream manager contract
    function setStreamManager(IStreamManager _streamManager) external;

    /// @notice Sets the signature manager contract address
    /// @dev Only callable by the contract owner
    /// @param _signatureManager The address of the signature manager contract
    function setSignatureManager(ISignatureManager _signatureManager) external;

    // ===================== Peg-in Request =====================

    /// @notice Generates a temporary Bitcoin address for peg-in operations
    /// @dev Creates a Taproot address with committee and user reimbursment paths for secure peg-in
    /// @param _rootstockDepositAddress The RSK address that will receive the RBTC
    /// @param _value The amount in satoshis to peg in (must match stream denomination)
    /// @param _btcReimbursementPubKey The user's Bitcoin public key (x-coordinate only, 32 bytes)
    /// @return temporaryPeginAddress The generated temporary Bitcoin address for deposit
    function getTemporaryPeginAddress(address _rootstockDepositAddress, uint64 _value, bytes32 _btcReimbursementPubKey)
        external
        returns (string memory temporaryPeginAddress);

    /// @notice Retrieves the stream position information for a given Bitcoin transaction hash
    /// @param btcTxHash The Bitcoin transaction hash to look up
    /// @return The stream position containing stream, packet, slot, and status information
    function getStreamPosition(bytes32 btcTxHash) external view returns (StreamPosition memory);

    /// @notice Registers a peg-in request transaction from Bitcoin
    /// @dev Validates the SPV proof and initiates the peg-in process
    /// @dev Emits PeginRequested event upon successful registration
    /// @param _peginRequestTxSPVProof The BTC SPV proof of the peg-in request transaction
    function requestPegin(BtcTxSPVProof calldata _peginRequestTxSPVProof) external;

    /// @notice Event emitted when a peg-in request is successfully registered
    /// @param committeeId The ID of the committee responsible for this peg-in
    /// @param requestPeginTxHash The hash of the peg-in request transaction
    /// @param acceptPeginTxHash The hash of the accept peg-in transaction
    /// @param vout The output index of the transaction
    /// @param streamId The stream ID where the funds will be placed
    /// @param packetNumber The packet number within the stream
    /// @param requestPeginInfo Temporary information needed for the accept phase
    /// @param prevoutData Data about the previous output being spent
    /// @param acceptPeginSignatureMessage The signature message for committee signing
    event PeginRequested(
        uint256 indexed committeeId,
        bytes32 indexed requestPeginTxHash,
        bytes32 indexed acceptPeginTxHash,
        uint64 vout,
        uint64 streamId,
        uint64 packetNumber,
        RequestPeginTempInfo requestPeginInfo,
        PrevoutData prevoutData,
        bytes acceptPeginSignatureMessage
    );

    /// @notice Retrieves the accept peg-in transaction hash for a given request transaction hash
    /// @param _btcTxHash The Bitcoin transaction hash of the peg-in request
    /// @return The accept peg-in transaction hash
    function getPeginRequest(bytes32 _btcTxHash) external view returns (bytes32);

    /// @notice Retrieves temporary information stored during peg-in request processing
    /// @param btcTxHash The Bitcoin transaction hash of the peg-in request
    /// @return The temporary information needed for the accept phase
    function getRequestPeginTempInfo(bytes32 btcTxHash) external view returns (RequestPeginTempInfo memory);

    // ===================== Accept Peg-in Request =====================

    /// @notice Accepts and registers a Bitcoin peg-in transaction to the committee account
    /// @dev Validates the SPV proof and completes the peg-in process
    /// @dev Emits PeginAccepted event upon successful acceptance
    /// @param _peginAcceptedTxSPVProof The BTC SPV proof of the accept peg-in transaction
    function acceptPegin(BtcTxSPVProof calldata _peginAcceptedTxSPVProof) external;

    /// @notice Event emitted when a peg-in is successfully accepted
    /// @param blockHash The Bitcoin block hash containing the accept transaction
    /// @param acceptPeginTxHash The hash of the accept peg-in transaction
    /// @param peginRequestTxHash The hash of the original peg-in request transaction
    /// @param vout The output index of the transaction
    /// @param streamPosition The final position of funds in the stream system
    /// @param speedUpPubKey The public key for speed-up transactions
    /// @param rskDestinationAddress The RSK address that received the RBTC
    /// @param rbtcAmount The amount of RBTC minted
    /// @param utxoScriptPubKey The script pubkey of the UTXO
    event PeginAccepted(
        bytes32 indexed blockHash,
        bytes32 indexed acceptPeginTxHash,
        bytes32 indexed peginRequestTxHash,
        uint64 vout,
        StreamPosition streamPosition,
        bytes32 speedUpPubKey,
        address rskDestinationAddress,
        uint256 rbtcAmount,
        bytes utxoScriptPubKey
    );

    // ===================== Peg-out Request =====================

    /// @notice Initiates a peg-out request to Bitcoin
    /// @dev Requires payment in RBTC and will revert if no filled slot is available
    /// @dev Emits PegoutRequested event upon successful initiation
    /// @param _userPubKey The user's compressed public key that will receive the Bitcoin funds
    function tryPegout(bytes calldata _userPubKey) external payable;

    /// @notice Registers the Bitcoin peg-out transaction to the user account
    /// @dev Validates the SPV proof and completes the peg-out process
    /// @dev Emits PegoutRegistered event upon successful registration
    /// @param _pegoutTxSPVProof The BTC SPV proof of the peg-out transaction
    function registerPegout(BtcTxSPVProof calldata _pegoutTxSPVProof) external;

    /// @notice Event emitted when a peg-out is successfully requested
    /// @param userPubKey The user's public key that will receive the Bitcoin funds
    /// @param committeeId The ID of the committee responsible for this peg-out
    /// @param pegoutSignatureHash The signature hash that committee members need to sign
    /// @param pegoutSignatureMessage The signature message for committee signing
    /// @param streamId The stream ID where the funds originated
    /// @param packetNumber The packet number within the stream
    /// @param slotId The slot ID within the packet
    /// @param amount The amount being peg-out in satoshis
    event PegoutRequested(
        bytes indexed userPubKey,
        uint256 indexed committeeId,
        bytes32 indexed pegoutSignatureHash,
        bytes pegoutSignatureMessage,
        uint64 streamId,
        uint64 packetNumber,
        uint64 slotId,
        uint64 amount
    );

    /// @notice Event emitted when a peg-out is successfully registered
    /// @param blockHash The Bitcoin block hash containing the peg-out transaction
    /// @param txHash The hash of the peg-out transaction
    /// @param acceptPeginTxHash The hash of the original accept peg-in transaction
    /// @param streamId The stream ID where the funds originated
    /// @param packetNumber The packet number within the stream
    /// @param slotId The slot ID within the packet
    event PegoutRegistered(
        bytes32 indexed blockHash,
        bytes32 indexed txHash,
        bytes32 indexed acceptPeginTxHash,
        uint64 streamId,
        uint64 packetNumber,
        uint64 slotId
    );

    function setUserTakeTimeout(uint256 _timeout) external;
    function setOperatorTakeTimeout(uint256 _timeout) external;
    function userTakeTimeout() external view returns (uint256);
    function operatorTakeTimeout() external view returns (uint256);

    function depositOperatorTakeProof(BtcTxSPVProof calldata _pegoutTxSPVProof) external;

    // ===================== Events =====================
    event UserTakeTimeoutUpdated(uint256 newTimeout);
    event OperatorTakeTimeoutUpdated(uint256 newTimeout);
    event OperatorTakeTriggered(
        bytes32 pegoutSignatureHash,
        uint256 committeeId,
        bytes32 acceptPeginTxHash,
        address operator,
        bytes userPubKey,
        uint256 userTakeCreatedAt,
        uint256 updatedAt,
        uint256 expireAt
    );

    event PacketClosed(uint64 indexed streamId, uint64 indexed packetNumber);

    // ===================== Errors =====================

    /// @notice Thrown when the Bitcoin manager address is set to zero
    error BitcoinManagerAddressZero();

    /// @notice Thrown when the committee registry address is set to zero
    error CommitteeRegistryAddressZero();

    /// @notice Thrown when the signature manager address is set to zero
    error SignatureManagerAddressZero();

    /// @notice Thrown when the stream manager address is set to zero
    error StreamManagerAddressZero();

    /// @notice Thrown when peg-out request amount exceeds uint64 limit
    /// @param amount The amount that exceeded the limit
    error PegoutRequestAmountExceedsUint64Limit(uint256 amount);

    /// @notice Thrown when a peg-in has already been requested for the given transaction
    /// @param btcTxHash The Bitcoin transaction hash that was already requested
    error PeginAlreadyRequested(bytes32 btcTxHash);

    /// @notice Thrown when trying to process a peg-in that hasn't been requested
    /// @param btcTxHash The Bitcoin transaction hash that wasn't requested
    error PeginNotRequested(bytes32 btcTxHash);

    /// @notice Thrown when the accept peg-in transaction hash doesn't match the expected value
    /// @param expected The expected transaction hash
    /// @param actual The actual transaction hash received
    error InvalidAcceptPeginTxHash(bytes32 expected, bytes32 actual);

    /// @notice Thrown when a peg-in has already been accepted
    /// @param btcTxHash The Bitcoin transaction hash that was already accepted
    error PeginAlreadyAccepted(bytes32 btcTxHash);

    /// @notice Thrown when the number of inputs doesn't match the expected count
    /// @param actual The actual number of inputs
    /// @param expected The expected number of inputs
    error IncorrectInputsNumber(uint256 actual, uint256 expected);

    /// @notice Thrown when the number of outputs doesn't match the expected count
    /// @param actual The actual number of outputs
    /// @param expected The expected number of outputs
    error IncorrectOutputsNumber(uint256 actual, uint256 expected);

    /// @notice Thrown when the provided public key is not in valid compressed format
    /// @param userPubKey The invalid public key that was provided
    error InvalidCompressedPubKey(bytes userPubKey);

    /// @notice Thrown when the transaction locktime doesn't match the expected value
    /// @param actual The actual locktime value
    /// @param expected The expected locktime value
    error InvalidLocktime(uint256 actual, uint256 expected);

    /// @notice Thrown when the Bitcoin transaction version doesn't match the expected value
    /// @param actual The actual version value
    /// @param expected The expected version value
    error InvalidBtcTxVersion(uint256 actual, uint256 expected);

    /// @notice Thrown when the slot state doesn't match the expected state
    /// @param actual The actual slot state
    /// @param expected The expected slot state
    error InvalidSlotState(SlotState actual, SlotState expected);

    /// @notice Thrown when the output index (vout) doesn't match the expected value
    /// @param actual The actual vout value
    /// @param expected The expected vout value
    error IncorrectVout(uint32 actual, uint32 expected);

    /// @notice Thrown when the output script doesn't match the expected format
    /// @param actual The actual script bytes
    /// @param expected The expected script bytes
    error IncorrectOutputScript(bytes actual, bytes expected);
    error InvalidTimeout(uint256 timeout);
    error InvalidPegStatus(PegStatus actual);
    error UserTakeTimeoutNotExpired(uint256 createdAt, uint256 expireAt);
    error UserTakeAlreadySigned(bytes32 pegoutSignatureHash);
    error OperatorTakeTimeoutNotExpired(uint256 createdAt, uint256 expireAt);
    error PegoutSignatureHashNotFound(bytes32 pegoutSignatureHash);
}
