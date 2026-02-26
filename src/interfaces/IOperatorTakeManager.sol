// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {BtcTxSPVProof} from "./IPegCommonTypes.sol";
import {StreamPosition} from "./IPegCommonTypes.sol";

/// @notice Information for operator take flow (stored in OperatorTakeManager)
struct OperatorTakeInfo {
    uint256 operatorTakeUpdatedAt;
    address operatorTakeAddress;
    bytes32 operatorTakePubKey;
    bytes32 operatorDisputePubKey;
    bytes32 pegoutId;
    int256 advanceFundsBlockNumber;
    bytes32 reimbursementKickoffTxid;
}

/// @notice Timeout settings for operator take flow
struct TakeTimeout {
    uint256 userTake;
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

    /// @notice Gets the current timeout settings
    function getTakeTimeout() external view returns (TakeTimeout memory);

    /// @notice Sets the timeout settings for user take and operator take
    function setTakeTimeout(TakeTimeout memory _takeTimeout) external;

    // ===================== Events =====================

    /// @notice Event emitted when advance funds are successfully registered
    event AdvanceFundsRegistered(
        bytes32 indexed blockHash,
        bytes32 indexed txid,
        bytes32 indexed acceptPeginTxid,
        bytes32 pegoutId,
        uint128 committeeId,
        StreamPosition streamInfo,
        bytes32 operatorTakePubKey
    );

    /// @notice Event emitted when operator take is triggered
    event OperatorTakeTriggered(
        bytes32 indexed pegoutTxid,
        OperatorTakeInfo operatorTakeInfo,
        StreamPosition streamPosition,
        uint256 updatedAt,
        uint256 expireAt
    );

    /// @notice Event emitted when timeouts are updated
    event TimeoutsUpdated(uint256 userTake, uint256 operatorTake);

    /// @notice Event emitted when reimbursement kickoff is successfully registered
    event ReimbursementKickoffRegistered(
        bytes32 indexed txid,
        bytes32 indexed acceptPeginTxid,
        bytes32 indexed pegoutId,
        uint128 committeeId,
        StreamPosition streamInfo,
        bytes32 operatorTakePubKey
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

    /// @notice Thrown when an invalid timeout value is provided (zero timeout)
    error InvalidTimeout(uint256 timeout);

    /// @notice Thrown when trying to trigger operator take before user take timeout has expired
    error UserTakeTimeoutNotExpired(uint256 createdAt, uint256 expireAt);

    /// @notice Thrown when trying to trigger operator take but user take was already signed
    error UserTakeAlreadySigned(bytes32 acceptPeginTxid);

    /// @notice Thrown when trying to trigger operator take before operator take timeout has expired
    error OperatorTakeTimeoutNotExpired(uint256 updatedAt, uint256 expireAt);
}
