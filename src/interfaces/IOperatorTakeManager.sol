// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {BtcTxSPVProof} from "./IPegCommonTypes.sol";
import {StreamPosition} from "./IPegCommonTypes.sol";
import {CompactPubKey} from "./IMemberRegistry.sol";

/// @notice Information for operator take flow (stored in OperatorTakeManager)
struct OperatorTakeInfo {
    uint256 operatorTakeUpdatedAt;
    address operatorTakeAddress;
    CompactPubKey operatorTakePubKey;
    CompactPubKey operatorDisputePubKey;
    bytes32 pegoutId;
    int256 advanceFundsBlockNumber;
    bytes32 reimbursementKickoffTxid;
}

/// @notice Per-stream timeout settings for a single stream
struct TakeTimeout {
    /// @notice Timeout in seconds for user take operations
    uint256 userTake;
    /// @notice Timeout in seconds for operator take operations
    uint256 operatorTake;
}

/// @title IOperatorTakeManager
/// @notice Interface for operator take flow: advance funds, kickoff, operator take, operator won
interface IOperatorTakeManager {
    /// @notice Registers the advance funds transaction submitted by the operator
    /// @dev Validates the SPV proof and updates the peg-out status accordingly
    /// @param _acceptPeginTxid The accept peg-in transaction id that it's being advanced
    /// @param _advanceFunds The BTC SPV proof of the advance funds transaction
    function registerAdvanceFunds(bytes32 _acceptPeginTxid, BtcTxSPVProof calldata _advanceFunds) external;

    /// @notice Registers the reimbursement kickoff transaction submitted by the operator
    /// @dev Validates the SPV proof and updates the peg-out status accordingly
    /// @param _acceptPeginTxid The accept peg-in transaction id that it's being reimbursed
    /// @param _kickoffSPV The BTC SPV proof of the reimbursement kickoff transaction
    function registerReimbursementKickoff(bytes32 _acceptPeginTxid, BtcTxSPVProof calldata _kickoffSPV) external;

    /// @notice Registers the cancel user take proof submitted by the operator
    /// @dev Validates the SPV proof
    /// @param _cancelUserTakeSPVProof The BTC SPV proof of the cancel user take transaction
    function registerCancelUserTake(BtcTxSPVProof calldata _cancelUserTakeSPVProof) external;

    /// @notice Deposits an operator take proof for a peg-out transaction
    /// @dev Validates the SPV proof and marks the slot as paid when operator takes over
    /// @dev Only callable when the peg status is KICKOFF and contract is unpaused
    /// @param _pegoutTxSPVProof The BTC SPV proof of the peg-out transaction
    function registerOperatorTake(BtcTxSPVProof calldata _pegoutTxSPVProof) external;

    /// @notice Deposits an operator won proof for a peg-out transaction
    /// @dev Validates the SPV proof and marks the slot as paid when operator takes over
    /// @dev Only callable when the peg status is REVEALED and contract is unpaused
    /// @param _pegoutTxSPVProof The BTC SPV proof of the operator won transaction
    function registerOperatorWon(BtcTxSPVProof calldata _pegoutTxSPVProof) external;

    /// @notice Triggers the operator take process for a peg-out when not all committee members sign within timeout
    /// @param _acceptPeginTxid The accept peg-in transaction id for the peg-out
    function triggerOperatorTake(bytes32 _acceptPeginTxid) external;

    /// @notice Gets temporary operator take information for a peg-out
    function getOperatorTakeInfo(bytes32 _acceptPeginTxid) external view returns (OperatorTakeInfo memory);

    /// @notice Returns the bitcoin block number where the cancel user take tx was mined
    function getCancelUserTakeTxBlockNumber(bytes32 _acceptPeginTxid) external view returns (int256 blockNumber);

    /// @notice Gets the timeout settings for a specific stream (auto-generated from public storage)
    /// @param streamId The stream identifier
    /// @return userTake Timeout in seconds for user take operations
    /// @return operatorTake Timeout in seconds for operator take operations
    function takeTimeouts(uint256 streamId) external view returns (uint256 userTake, uint256 operatorTake);

    /// @notice Sets the timeout settings for a specific stream
    /// @dev Only callable by the contract owner
    /// @param _streamId The stream identifier
    /// @param _timeout The new timeout settings
    function setTakeTimeout(uint64 _streamId, TakeTimeout memory _timeout) external;

    // ===================== Events =====================

    /// @notice Event emitted when advance funds are successfully registered
    event AdvanceFundsRegistered(
        bytes32 indexed blockHash,
        bytes32 indexed txid,
        bytes32 indexed acceptPeginTxid,
        bytes32 pegoutId,
        uint128 committeeId,
        StreamPosition streamInfo,
        CompactPubKey operatorTakePubKey
    );

    /// @notice Event emitted when cancel user take spv proof is registered
    event CancelUserTakeRegistered(bytes32 indexed acceptPeginTxid);

    /// @notice Event emitted when operator take is triggered
    event OperatorTakeTriggered(
        bytes32 indexed pegoutTxid,
        OperatorTakeInfo operatorTakeInfo,
        StreamPosition streamPosition,
        uint256 updatedAt,
        uint256 expireAt
    );

    /// @notice Event emitted when the timeout settings are updated for a specific stream
    /// @param streamId The stream identifier
    /// @param newTimeout The new timeout settings
    event TakeTimeoutUpdated(uint64 indexed streamId, TakeTimeout newTimeout);

    /// @notice Event emitted when reimbursement kickoff is successfully registered
    event ReimbursementKickoffRegistered(
        bytes32 indexed txid,
        bytes32 indexed acceptPeginTxid,
        bytes32 indexed pegoutId,
        uint128 committeeId,
        StreamPosition streamInfo,
        CompactPubKey operatorTakePubKey
    );

    // ===================== Errors =====================

    /// @notice Thrown when the advance funds amount is lower than the expected peg-out amount
    error WrongUserAmount(uint256 actual, uint256 expected);

    /// @notice Thrown when the reimbursement kickoff txid does not match the expected value
    error ReimbursementKickoffTxidNotMatch(bytes32 actual, bytes32 expected);

    /// @notice Thrown when the input txid Operator Won transaction does not match the expected value
    error InputRevealedTxidNotMatch(bytes32 actual, bytes32 expected);

    /// @notice Thrown when the operator take transaction id does not match the expected value
    error OperatorTakeTxidNotMatch(bytes32 actual, bytes32 expected);

    /// @notice Thrown when the operator won transaction id does not match the expected value
    error OperatorWonTxidNotMatch(bytes32 actual, bytes32 expected);

    /// @notice Thrown when the operator address does not match the expected operator that should advance the funds
    error OperatorTakeAddressNotMatch(address expectedOperator, address actualOperator);

    /// @notice Thrown when the number of inputs in the kickoff transaction doesn't match the expected count
    error InvalidKickoffInputCount(uint256 actual, uint256 expected);

    /// @notice Thrown when the slot id in the kickoff transaction doesn't match the expected slot id
    error InvalidSlotId(uint32 actual, uint64 expected);

    /// @notice Thrown when the reimbursement kickoff transaction is mined before the advance funds transaction
    error ReimbursementKickoffBeforeAdvanceFunds(int256 advanceFundsBlockNumber, int256 reimbursementKickoffBlockNumber);

    /// @notice Thrown when operator take data is not found for a given accept peg-in txid and operator address
    error OperatorTakeDataNotFound(bytes32 acceptPeginTxid, address operatorAddress);

    /// @notice Thrown when the per-stream timeout array has incorrect length
    error InvalidTimeoutsLength();

    /// @notice Thrown when an invalid timeout value is provided (zero timeout)
    error InvalidTimeout(uint256 timeout);

    /// @notice Thrown when trying to trigger operator take before user take timeout has expired
    error UserTakeTimeoutNotExpired(uint256 createdAt, uint256 expireAt);

    /// @notice Thrown when trying to trigger operator take before operator take timeout has expired
    error OperatorTakeTimeoutNotExpired(uint256 updatedAt, uint256 expireAt);

    /// @notice Thrown when operator is trying to advance funds before cancelling user take flow
    error AdvanceFundsBeforeCancelUserTake(bytes32 acceptPeginTxid);

    /// @notice Thrown when trying to register an already registered cancel user take spv proof
    /// @param acceptPeginTxid The accept pegin txid associated with the pegout for which user take flow is already cancelled
    error CancelUserTakeAlreadyRegistered(bytes32 acceptPeginTxid);
}
