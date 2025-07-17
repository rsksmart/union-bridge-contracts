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
    COMPLETED
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

struct PegManagerSettings {
    /// @notice Timeout for the user to take the pegout
    /// @dev This is the time the members has to sign the pegout transaction
    uint256 userTakeTimeout; // Timeout for the user to take the pegout
    /// @notice Timeout for the operator to take the pegout
    /// @dev This is the time the operator has to advance the funds to the user and present the proof
    uint256 operatorTakeTimeout; // Timeout for the operator to take the pegout
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
    /// @param streamPosition The struct with the position information (stream, packet, slot, status)
    /// @param requestPeginInfo Temporary information needed for the accept phase
    /// @param prevoutData Data about the previous output being spent
    /// @param acceptPeginSignatureMessage The signature message for committee signing
    event PeginRequested(
        uint256 indexed committeeId,
        bytes32 indexed requestPeginTxHash,
        bytes32 indexed acceptPeginTxHash,
        uint64 vout,
        StreamPosition streamPosition,
        RequestPeginTempInfo requestPeginInfo,
        PrevoutData prevoutData,
        bytes acceptPeginSignatureMessage
    );

    /// @notice Gets the accept peg-in transaction hash for a given request transaction hash
    /// @param _btcTxHash The Bitcoin transaction hash of the peg-in request
    /// @return The accept peg-in transaction hash
    function getPeginRequest(bytes32 _btcTxHash) external view returns (bytes32);

    /// @notice Gets temporary information stored during peg-in request processing
    /// @param btcTxHash The Bitcoin transaction hash of the peg-in request
    /// @return The temporary information needed for the accept phase
    function getRequestPeginTempInfo(bytes32 btcTxHash) external view returns (RequestPeginTempInfo memory);

    /// @notice Gets temporary information stored during peg-out processing
    /// @param acceptPeginTxHash The accept peg-in transaction hash
    /// @return The temporary information needed for peg-out processing
    function getPegoutTempInfo(bytes32 acceptPeginTxHash) external view returns (PegoutTempInfo memory);

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
    function registerUserTake(BtcTxSPVProof calldata _pegoutTxSPVProof) external;

    /// @notice Gets the peg-out signature hash for a specific stream, packet, and slot
    /// @param streamId The stream identifier
    /// @param packetNumber The packet number within the stream
    /// @param slotId The slot identifier within the packet
    /// @return The peg-out signature hash
    function getPegoutSignatureHash(uint64 streamId, uint64 packetNumber, uint64 slotId)
        external
        view
        returns (bytes32);

    /// @notice Event emitted when a peg-out is successfully requested
    /// @param userPubKey The user's public key that will receive the Bitcoin funds
    /// @param committeeId The ID of the committee responsible for this peg-out
    /// @param pegoutSignatureHash The signature hash that committee members need to sign
    /// @param pegoutSignatureMessage The signature message for committee signing
    /// @param streamId The stream ID where the funds originated
    /// @param packetNumber The packet number within the stream
    /// @param slotId The slot ID within the packet
    /// @param amount The amount being peg-out in satoshis
    /// @param pegoutId The unique identifier for this peg-out operation
    event PegoutRequested(
        bytes indexed userPubKey,
        uint256 indexed committeeId,
        bytes32 indexed pegoutSignatureHash,
        bytes pegoutSignatureMessage,
        uint64 streamId,
        uint64 packetNumber,
        uint64 slotId,
        uint64 amount,
        bytes32 pegoutId
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

    /// @notice Sets User Take Timeout
    /// @dev Allows the contract owner to update the timeout for user take actions
    /// @param _timeout The new timeout value in seconds
    /// @dev Emits UserTakeTimeoutUpdated event upon successful update
    /// @dev Reverts if the timeout is zero
    function setUserTakeTimeout(uint256 _timeout) external;

    /// @notice Sets Operator Take Timeout
    /// @dev Allows the contract owner to update the timeout for operator take actions
    /// @param _timeout The new timeout value in seconds
    /// @dev Emits OperatorTakeTimeoutUpdated event upon successful update
    /// @dev Reverts if the timeout is zero
    function setOperatorTakeTimeout(uint256 _timeout) external;

    /// @notice Gets the current timeout duration for user take operations
    /// @return The timeout duration in seconds
    function userTakeTimeout() external view returns (uint256);

    /// @notice Gets the current timeout duration for operator take operations
    /// @return The timeout duration in seconds
    function operatorTakeTimeout() external view returns (uint256);

    /// @notice Registers the Bitcoin peg-out transaction to the operator account
    /// @dev Validates the SPV proof and marks the slot as paid when operator takes over
    /// @dev Only callable when the peg status is OPERATOR_TAKE
    /// @dev Emits PegoutRegistered event upon successful deposit
    /// @param _pegoutTxSPVProof The BTC SPV proof of the operator take peg-out transaction
    function registerOperatorTake(BtcTxSPVProof calldata _pegoutTxSPVProof) external;

    /// @notice Triggers the operator take process for a peg-out when not all committee members sign within timeout
    /// @dev This function can be called after a User Take expiration or after an Operator Take expiration
    /// @dev Each case has its own timeout and before triggering the operator take (after a User Take expiration)
    /// @dev signatures should be checked to see if the User Take was already signed
    /// @dev Partial signatures are used to skip those operators that have not signed the User Take
    /// @dev Emits OperatorTakeTriggered event upon successful triggering
    /// @param _pegoutSignatureHash The signature hash of the peg-out request
    function triggerOperatorTake(bytes32 _pegoutSignatureHash) external;

    // ===================== Events =====================

    /// @notice Event emitted when the user take timeout is updated
    /// @param newTimeout The new timeout duration in seconds
    event UserTakeTimeoutUpdated(uint256 newTimeout);

    /// @notice Event emitted when the operator take timeout is updated
    /// @param newTimeout The new timeout duration in seconds
    event OperatorTakeTimeoutUpdated(uint256 newTimeout);

    /// @notice Event emitted when operator take is triggered for a peg-out
    /// @param pegoutSignatureHash The signature hash of the peg-out request
    /// @param committeeId The ID of the committee responsible for this peg-out
    /// @param acceptPeginTxHash The hash of the accept peg-in transaction
    /// @param operator The address of the operator that will take over
    /// @param userPubKey The user's public key that will receive the Bitcoin funds
    /// @param userTakeCreatedAt The timestamp when the user take was created
    /// @param updatedAt The timestamp when the operator take was triggered
    /// @param expireAt The timestamp when the operator take timeout expires
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

    /// @notice Event emitted when a packet is closed in the stream
    /// @param streamId The ID of the stream where the packet was closed
    /// @param packetNumber The number of the packet that was closed
    /// @dev Indicates that all slots in the packet have been processed and pegged out
    /// @dev This event is used to track the lifecycle of packets in the stream
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

    /// @notice Thrown when an invalid timeout value is provided (zero timeout)
    /// @param timeout The invalid timeout value that was provided
    error InvalidTimeout(uint256 timeout);

    /// @notice Thrown when the peg status is not valid for the current operation
    /// @param actual The actual peg status that was found
    error InvalidPegStatus(PegStatus actual);

    /// @notice Thrown when trying to trigger operator take before user take timeout has expired
    /// @param createdAt The timestamp when the user take was created
    /// @param expireAt The timestamp when the user take timeout expires
    error UserTakeTimeoutNotExpired(uint256 createdAt, uint256 expireAt);

    /// @notice Thrown when trying to trigger operator take but user take was already signed
    /// @param pegoutSignatureHash The signature hash of the peg-out request
    error UserTakeAlreadySigned(bytes32 pegoutSignatureHash);

    /// @notice Thrown when trying to trigger operator take before operator take timeout has expired
    /// @param createdAt The timestamp when the operator take was updated
    /// @param expireAt The timestamp when the operator take timeout expires
    error OperatorTakeTimeoutNotExpired(uint256 createdAt, uint256 expireAt);

    /// @notice Thrown when a peg-out signature hash is not found in the system
    /// @param pegoutSignatureHash The signature hash that was not found
    error PegoutSignatureHashNotFound(bytes32 pegoutSignatureHash);

    /// @notice Thrown when the operator address does not match the expected operator that should advance the funds
    /// @param expectedOperator The expected operator address that should take the pegout
    /// @param actualOperator The actual operator address that was provided
    error OperatorTakeAddressNotMatch(address expectedOperator, address actualOperator);
}
