// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {BitcoinSignatureData} from "./IBitcoinManager.sol";
import {SlotState} from "./IStreamManager.sol";
import {IPausable} from "./IPausable.sol";
import {BtcTxSPVProof, StreamPosition, PegoutTempInfo, PegStatus} from "./IPegCommonTypes.sol";

/// @title IPegoutManager
/// @notice Interface for managing peg-out operations
interface IPegoutManager is IPausable {
    /// @notice Gets temporary information stored during peg-out processing
    /// @param acceptPeginTxid The accept peg-in transaction id
    /// @return The temporary information needed for peg-out processing
    function getPegoutTempInfo(bytes32 acceptPeginTxid) external view returns (PegoutTempInfo memory);

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
    function getPegoutTxid(uint64 streamId, uint64 packetNumber, uint64 slotId) external view returns (bytes32);

    /// @notice Event emitted when a peg-out is successfully requested
    /// @param userPubKey The user's public key that will receive the Bitcoin funds
    /// @param committeeId The ID of the committee responsible for this peg-out
    /// @param pegoutSignatureData The signature data for committee signing
    /// @param streamId The stream ID where the funds originated
    /// @param packetNumber The packet number within the stream
    /// @param slotId The slot ID within the packet
    /// @param amount The amount being peg-out in satoshis
    /// @param pegoutId The unique identifier for this peg-out operation
    event PegoutRequested(
        bytes userPubKey,
        uint256 indexed committeeId,
        BitcoinSignatureData pegoutSignatureData,
        uint64 streamId,
        uint64 packetNumber,
        uint64 slotId,
        uint64 amount,
        bytes32 pegoutId
    );

    /// @notice Event emitted when a peg-out is successfully registered
    /// @param blockHash The Bitcoin block hash containing the peg-out transaction
    /// @param txid The hash of the peg-out transaction
    /// @param acceptPeginTxid The hash of the original accept peg-in transaction
    /// @param committeeId The ID of the committee responsible for this peg-out
    /// @param streamId The stream ID where the funds originated
    /// @param packetNumber The packet number within the stream
    /// @param slotId The slot ID within the packet
    event PegoutRegistered(
        bytes32 indexed blockHash,
        bytes32 indexed txid,
        bytes32 indexed acceptPeginTxid,
        uint128 committeeId,
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
    /// @param _pegoutTxid The transaction id of the peg-out request
    function triggerOperatorTake(bytes32 _pegoutTxid) external;

    // ===================== Events =====================

    /// @notice Event emitted when the user take timeout is updated
    /// @param newTimeout The new timeout duration in seconds
    event UserTakeTimeoutUpdated(uint256 newTimeout);

    /// @notice Event emitted when the operator take timeout is updated
    /// @param newTimeout The new timeout duration in seconds
    event OperatorTakeTimeoutUpdated(uint256 newTimeout);

    /// @notice Event emitted when operator take is triggered for a peg-out
    /// @param pegoutTxid The transaction id of the peg-out request
    /// @param pegoutInfo Complete pegout temporary information including operator details
    /// @param streamPosition Stream position information including slot ID
    /// @param updatedAt The timestamp when the operator take was triggered
    /// @param expireAt The timestamp when the operator take timeout expires
    event OperatorTakeTriggered(
        bytes32 pegoutTxid,
        PegoutTempInfo pegoutInfo,
        StreamPosition streamPosition,
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

    /// @notice Thrown when the member registry address is set to zero
    error MemberRegistryAddressZero();

    /// @notice Thrown when trying to process a peg-out for a peg-in that hasn't been requested
    /// @param btcTxid The Bitcoin transaction id that wasn't requested
    error PeginNotRequested(bytes32 btcTxid);

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
    /// @param pegoutTxid The signature hash of the peg-out request
    error UserTakeAlreadySigned(bytes32 pegoutTxid);

    /// @notice Thrown when trying to trigger operator take before operator take timeout has expired
    /// @param createdAt The timestamp when the operator take was updated
    /// @param expireAt The timestamp when the operator take timeout expires
    error OperatorTakeTimeoutNotExpired(uint256 createdAt, uint256 expireAt);

    /// @notice Thrown when a peg-out signature hash is not found in the system
    /// @param pegoutTxid The signature hash that was not found
    error PegoutTxidNotFound(bytes32 pegoutTxid);

    /// @notice Thrown when the operator address does not match the expected operator that should advance the funds
    /// @param expectedOperator The expected operator address that should take the pegout
    /// @param actualOperator The actual operator address that was provided
    error OperatorTakeAddressNotMatch(address expectedOperator, address actualOperator);
}
