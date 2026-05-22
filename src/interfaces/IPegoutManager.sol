// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BitcoinSignatureData} from "./IBitcoinManager.sol";
import {SlotState} from "./IStreamManager.sol";
import {BtcTxSPVProof, StreamPosition} from "./IPegCommonTypes.sol";

/// @notice Start info stored in PegoutManager (user take / pegout creation only)
struct PegoutStartInfo {
    bytes userPubKey;
    uint256 createdAt;
    bytes32 pegoutTxid;
}

struct PegoutRequest {
    /// @notice The user's public key that will receive the Bitcoin funds
    bytes userPubKey;
    /// @notice user RSK address in case a refund is needed.
    address userAddress;
}

/// @title IPegoutManager
/// @notice Interface for managing peg-out operations
interface IPegoutManager {
    /// @notice Gets start information stored during peg-out creation
    /// @param _acceptPeginTxid The accept peg-in transaction id
    /// @return The start info (userPubKey, createdAt)
    function getPegoutStartInfo(bytes32 _acceptPeginTxid) external view returns (PegoutStartInfo memory);

    // ===================== Peg-out Request =====================

    /// @notice Initiates a peg-out operation by locking a slot and preparing the peg-out transaction
    /// @notice Reverts if a pegout is already in progress for the same stream
    /// @dev This function LOCKS a slot in the appropriate stream and prepares the peg-out transaction
    /// @dev Requires payment in RBTC and will revert if no filled slot is available
    /// @dev The user must send the exact amount of RBTC they want to peg-out
    /// @dev Emits PegoutRequested event upon successful initiation
    /// @dev Only callable when contract is unpaused
    /// @param _userPubKey The user's compressed public key that will receive the Bitcoin funds
    function tryPegout(bytes calldata _userPubKey) external payable;

    /// @notice Registers the Bitcoin peg-out transaction to the user account
    /// @dev This function validates the peg-out transaction and marks the slot as COMPLETED
    /// @dev The transaction must spend the accept peg-in output and pay to the user's address
    /// @dev Emits the PegoutRegistered event
    /// @dev Only callable when contract is unpaused
    /// @param _pegoutTxSPVProof The BTC SPV proof of the peg-out transaction
    function registerUserTake(BtcTxSPVProof calldata _pegoutTxSPVProof) external;

    /// @notice Get queue size for enqueued peg-out requests for a specific stream
    /// @param _streamId The stream identifier
    /// @return The number of enqueued peg-out requests for the specified stream
    function getPegoutQueueLength(uint64 _streamId) external view returns (uint64);

    /// @notice Enqueues a peg-out request for a specific stream
    /// @dev This function allows users to enqueue their peg-out requests where there is a pegout in process
    /// @param _userPubKey The user's compressed public key that will receive the Bitcoin funds
    function enqueuePegout(bytes memory _userPubKey) external payable;

    /// @notice Dequeues a peg-out request for processing for a specific stream
    /// @dev Should be called from the user that enqueued a pegout
    /// @param _streamId The stream identifier
    function dequeuePegout(uint64 _streamId) external;

    /// @notice Tries to process an enqueued peg-out request for a specific stream
    /// @param _streamId The stream identifier
    function tryProcessEnqueuedPegout(uint64 _streamId) external;

    // ===================== Events =====================

    /// @notice Event emitted when a peg-out is successfully requested
    /// @param userPubKey The user's public key that will receive the Bitcoin funds
    /// @param committeeId The ID of the committee responsible for this peg-out
    /// @param pegoutSignatureData The signature data for committee signing
    /// @param streamId The stream ID where the funds originated
    /// @param packetNumber The packet number within the stream
    /// @param slotId The slot ID within the packet
    /// @param amount The amount being peg-out in satoshis
    event PegoutRequested(
        bytes userPubKey,
        uint256 indexed committeeId,
        BitcoinSignatureData pegoutSignatureData,
        uint64 streamId,
        uint64 packetNumber,
        uint64 slotId,
        uint64 amount
    );

    /// @notice Event emitted when a peg-out is successfully registered
    /// @param blockHash The Bitcoin block hash containing the peg-out transaction
    /// @param txid The hash of the peg-out transaction
    /// @param acceptPeginTxid The txid of the original accept peg-in transaction
    /// @param committeeId The ID of the committee responsible for this peg-out
    /// @param streamInfo The stream position information related to this peg-out
    event PegoutRegistered(
        bytes32 indexed blockHash,
        bytes32 indexed txid,
        bytes32 indexed acceptPeginTxid,
        uint128 committeeId,
        StreamPosition streamInfo
    );

    /// @notice Event emitted when a peg-out request is enqueued
    /// @param streamId The stream identifier for which the peg-out request is enqueued
    /// @param userPubKey The user's public key that will receive the Bitcoin funds
    /// @param userAddress The user's RSK address in case a refund is needed
    event PegoutEnqueued(uint64 indexed streamId, bytes userPubKey, address userAddress);

    /// @notice Event emitted when a peg-out request is dequeued for processing
    /// @param streamId The stream identifier for which the peg-out request is dequeued
    /// @param userPubKey The user's public key that will receive the Bitcoin funds
    /// @param userAddress The user's RSK address in case a refund is needed
    event PegoutDequeued(uint64 indexed streamId, bytes userPubKey, address userAddress);

    // ===================== Errors =====================

    /// @notice Thrown when peg-out request amount exceeds uint64 limit
    /// @param amount The amount that exceeded the limit
    error PegoutRequestAmountExceedsUint64Limit(uint256 amount);

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

    /// @notice Thrown when the pegout queue has reached its maximum size
    /// @param streamId The stream identifier
    error PegoutQueueFull(uint64 streamId);

    /// @notice Thrown when there are no enqueued peg-outs to process
    /// @param streamId The stream identifier for which there are no enqueued peg-outs to process
    error NoEnqueuedPegout(uint64 streamId);

    /// @notice Thrown when there are no free filled slots available for peg-out in the specified stream
    /// @param streamId The stream identifier
    /// @param queueLength The current length of the peg-out queue for the stream
    /// @param remainingFilledSlots The number of remaining filled slots available for peg-out in the stream
    error NoFreeFilledSlot(uint64 streamId, uint64 queueLength, uint64 remainingFilledSlots);

    /// @notice Thrown when trying to process an enqueued peg-out but the peg-out data is not found in the queue
    /// @param streamId The stream identifier for which the peg-out data was not found
    /// @param userAddress The user's RSK address associated with the peg-out request that was not found
    error PegoutNotFoundInQueue(uint64 streamId, address userAddress);

    /// @notice Thrown when RSK transfer fails
    /// @param userAddress The user's address
    /// @param amount The amount that failed to transfer
    error FailedToSendRSK(address userAddress, uint256 amount);

    /// @notice Thrown when trying to process a peg-out but there is already an enqueued peg-out for the same stream
    /// @param streamId The stream identifier for which there is already an enqueued peg-out
    /// @param queueLength The current length of the peg-out queue for the stream
    error EnqueuedPegoutsForStream(uint64 streamId, uint64 queueLength);

    /// @notice Thrown when a peg-out txid is not found for the given accept peg-in transaction id
    /// @param acceptPeginTxid The accept peg-in transaction that doesn't have a pegout txid associated.
    error PegoutNotFoundForPegin(bytes32 acceptPeginTxid);
}
