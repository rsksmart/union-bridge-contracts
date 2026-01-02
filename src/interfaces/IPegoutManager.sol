// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {BitcoinSignatureData} from "./IBitcoinManager.sol";
import {SlotState} from "./IStreamManager.sol";
import {IPausable} from "./IPausable.sol";
import {BtcTxSPVProof, StreamPosition, PegStatus} from "./IPegCommonTypes.sol";

/// @notice Temporary information stored during peg-out processing
/// @dev Contains data needed for peg-out transaction validation
struct PegoutTempInfo {
    /// @notice The user's public key that will receive the Bitcoin funds
    bytes userPubKey;
    /// @notice Timestamp when the peg-out was initially created
    uint256 createdAt;
    /// @notice Timestamp when the operator take was last updated/triggered
    uint256 operatorTakeUpdatedAt;
    /// @notice The committee ID responsible for signing this peg-out
    uint128 committeeId;
    /// @notice The operator address that will advance the funds to the user
    address takeOperatorAddress;
    /// @notice The dispute public key (covenantPubKey) of the selected operator for operator-take transactions (x-coordinate only)
    bytes32 operatorDisputePubKey;
    /// @notice The unique identifier for this peg-out operation
    bytes32 pegoutId;
    /// @notice Block number when advance funds was mined
    int256 advanceFundsBlockNumber;
    /// @notice The transaction id of the reimbursement kickoff transaction
    bytes32 reimbursementKickoffTxid;
}

/// @notice Settings for the PegoutManager contract
/// @dev Contains timeout configurations for peg-out operations
struct PegoutManagerSettings {
    /// @notice Timeout for the user to take the pegout
    /// @dev This is the time the members have to sign the pegout transaction
    uint256 userTakeTimeout; // Timeout for the user to take the pegout
    /// @notice Timeout for the operator to take the pegout
    /// @dev This is the time the operator has to advance the funds to the user and present the proof
    uint256 operatorTakeTimeout; // Timeout for the operator to take the pegout
}

/// @title IPegoutManager
/// @notice Interface for managing peg-out operations
interface IPegoutManager is IPausable {
    /// @notice Gets temporary information stored during peg-out processing
    /// @param acceptPeginTxid The accept peg-in transaction id
    /// @return The temporary information needed for peg-out processing
    function getPegoutTempInfo(bytes32 acceptPeginTxid) external view returns (PegoutTempInfo memory);

    // ===================== Peg-out Request =====================

    /// @notice Initiates a peg-out request to Bitcoin
    /// @notice Reverts if a pegout is already in progress for the same stream
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
    /// @param streamInfo The stream position information related to this peg-out
    event PegoutRegistered(
        bytes32 indexed blockHash,
        bytes32 indexed txid,
        bytes32 indexed acceptPeginTxid,
        uint128 committeeId,
        StreamPosition streamInfo
    );

    /// @notice Event emitted when advance funds are successfully registered
    /// @param blockHash The Bitcoin block hash containing the advance funds transaction
    /// @param txid The hash of the advance funds transaction
    /// @param acceptPeginTxid The hash of the original accept peg-in transaction
    /// @param pegoutId The unique identifier for this peg-out operation
    /// @param committeeId The ID of the committee responsible for this advance funds
    /// @param streamInfo The stream position information related to this advance funds
    event AdvanceFundsRegistered(
        bytes32 indexed blockHash,
        bytes32 indexed txid,
        bytes32 indexed acceptPeginTxid,
        bytes32 pegoutId,
        uint128 committeeId,
        StreamPosition streamInfo
    );

    event ReimbursementKickoffRegistered(
        bytes32 indexed txid, bytes32 indexed acceptPeginTxid, uint128 committeeId, StreamPosition streamInfo
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

    /// @notice Registers the advance funds transaction submitted by the operator
    /// @dev Validates the SPV proof and updated the peg-out status accordingly
    /// @param acceptPeginTxid The accept peg-in transaction id that it's being advanced
    /// @param _advanceFunds The BTC SPV proof of the advance funds transaction
    function registerAdvanceFunds(bytes32 acceptPeginTxid, BtcTxSPVProof calldata _advanceFunds) external;

    /// @notice Registers the reimbursement kickoff transaction submitted by the operator
    /// @dev Validates the SPV proof and updates the peg-out status accordingly
    /// @param acceptPeginTxid The accept peg-in transaction id that it's being reimbursed
    /// @param _kickoffSPV The BTC SPV proof of the reimbursement kickoff transaction
    function registerReimbursementKickoff(bytes32 acceptPeginTxid, BtcTxSPVProof calldata _kickoffSPV) external;

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

    /// @notice Thrown when the reimbursement kickoff transaction is mined before the advance funds transaction
    /// @param advanceFundsBlockNumber The block number when advance funds was mined
    /// @param reimbursementKickoffBlockNumber The block number when reimbursement kickoff was mined
    error ReimbursementKickoffBeforeAdvanceFunds(int256 advanceFundsBlockNumber, int256 reimbursementKickoffBlockNumber);

    /// @notice Thrown when the advance funds amount is lower than the expected peg-out amount
    /// @param actual The actual amount in satoshis of the advance funds transaction
    /// @param expected The expected amount in satoshis that should be advanced
    error WrongUserAmount(uint256 actual, uint256 expected);

    /// @notice Thrown when the reimbursement kickoff txid does not match the expected value
    /// @param expected The expected reimbursement kickoff txid
    /// @param actual The actual reimbursement kickoff txid provided
    error ReimbursementKickoffTxidNotMatch(bytes32 expected, bytes32 actual);

    /// @notice Thrown when operator take data is not found for a given accept peg-in txid and operator address
    /// @param acceptPeginTxid The accept peg-in transaction id
    /// @param operatorAddress The operator address for which the data was not found
    error OperatorTakeDataNotFound(bytes32 acceptPeginTxid, address operatorAddress);

    /// @notice Thrown when the operator take transaction id does not match the expected value
    /// @param expected The expected operator take transaction id
    /// @param actual The actual operator take transaction id provided
    error OperatorTakeTxidNotMatch(bytes32 expected, bytes32 actual);
}
