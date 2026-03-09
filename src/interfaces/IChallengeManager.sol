// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {BtcTxSPVProof} from "./IPegCommonTypes.sol";
import {StreamPosition} from "./IPegCommonTypes.sol";

/// @notice Information stored during challenge processing
/// @dev Contains data needed for challenge transaction validation
struct ChallengeInfo {
    /// @notice The transaction id of the challenge transaction
    bytes32 challengeTxid;
    /// @notice The transaction id of the input reveal transaction
    bytes32 revealTxid;
}

/// @title IChallengeManager
/// @notice Interface for managing challenge operations
interface IChallengeManager {
    /// @notice Gets the challenge information for a given accept peg-in transaction id
    /// @param _acceptPeginTxid The accept peg-in transaction id
    /// @return The challenge information
    function getChallengeInfo(bytes32 _acceptPeginTxid) external view returns (ChallengeInfo memory);

    /// @notice Registers a challenge for a peg-out transaction
    /// @dev Validates the SPV proof and updates the peg-out status accordingly
    /// @param _acceptPeginTxid The accept peg-in transaction id that is being challenged
    /// @param _challenge The BTC SPV proof of the challenge transaction
    function registerChallenge(bytes32 _acceptPeginTxid, BtcTxSPVProof calldata _challenge) external;

    /// @notice Registers an input revealed for a challenge transaction
    /// @dev Validates the SPV proof and updates the challenge status accordingly
    /// @param _acceptPeginTxid The accept peg-in transaction id that is being challenged
    /// @param _inputRevealed The BTC SPV proof of the input revealed transaction
    function registerInputRevealed(bytes32 _acceptPeginTxid, BtcTxSPVProof memory _inputRevealed) external;

    /// @notice Registers an input not revealed for a challenge transaction
    /// @dev Validates the SPV proof and updates the challenge status accordingly
    /// @param _acceptPeginTxid The accept peg-in transaction id that is being challenged
    /// @param _inputNotRevealed The BTC SPV proof of the input not revealed transaction
    function registerInputNotRevealed(bytes32 _acceptPeginTxid, BtcTxSPVProof calldata _inputNotRevealed) external;

    /// @notice Registers a stop operator won for a reveal transaction
    /// @dev Validates the SPV proof and updates the challenge status accordingly
    /// @param _acceptPeginTxid The accept peg-in transaction id that is being challenged
    /// @param _stopOperatorWon The BTC SPV proof of the stop operator won transaction
    function registerStopOperatorWon(bytes32 _acceptPeginTxid, BtcTxSPVProof calldata _stopOperatorWon) external;

    // ===================== Events =====================
    /// @notice Event emitted when a challenge is registered for a peg-out
    /// @param txid The hash of the challenge transaction
    /// @param acceptPeginTxid The txid of the original accept peg-in transaction
    /// @param committeeId The ID of the committee responsible for this challenge
    /// @param streamInfo The stream position information related to this challenge
    event ChallengeRegistered(
        bytes32 indexed txid, bytes32 indexed acceptPeginTxid, uint128 committeeId, StreamPosition streamInfo
    );

    /// @notice Event emitted when an input is not revealed for a challenge
    /// @param txid The hash of the input not revealed transaction
    /// @param acceptPeginTxid The txid of the original accept peg-in transaction
    /// @param committeeId The ID of the committee responsible for this pegout
    /// @param streamInfo The stream position information related to this pegout
    event InputNotRevealedRegistered(
        bytes32 indexed txid, bytes32 indexed acceptPeginTxid, uint128 committeeId, StreamPosition streamInfo
    );

    /// @notice Event emitted when a stop operator won is registered for a reveal transaction
    /// @param txid The hash of the stop operator won transaction
    /// @param acceptPeginTxid The txid of the original accept peg-in transaction
    /// @param committeeId The ID of the committee responsible for this pegout
    /// @param streamInfo The stream position information related to this pegout
    event StopOperatorWonRegistered(
        bytes32 indexed txid, bytes32 indexed acceptPeginTxid, uint128 committeeId, StreamPosition streamInfo
    );

    /// @notice Event emitted when an input is revealed for a challenge
    /// @param txid The hash of the reveal transaction
    /// @param acceptPeginTxid The txid of the original accept peg-in transaction
    /// @param committeeId The ID of the committee responsible for this pegout
    /// @param streamInfo The stream position information related to this pegout
    event RevealRegistered(
        bytes32 indexed txid, bytes32 indexed acceptPeginTxid, uint128 committeeId, StreamPosition streamInfo
    );

    // ===================== Errors =====================
    /// @notice Thrown when the reimbursement kickoff txid does not match the expected value
    /// @param actual The actual reimbursement kickoff txid provided
    /// @param expected The expected reimbursement kickoff txid
    error ReimbursementKickoffTxidNotMatch(bytes32 actual, bytes32 expected);

    /// @notice Thrown when the challenge transaction id does not match the expected value
    /// @param actual The actual transaction id
    /// @param expected The expected transaction id
    error ChallengeTxidNotMatch(bytes32 actual, bytes32 expected);

    /// @notice Thrown when the reveal transaction id does not match the expected value
    /// @param input1txid The txid for the first input
    /// @param input2txid The txid for the second input
    /// @param expectedTxid The expected transaction id
    error RevealTxidNotMatch(bytes32 input1txid, bytes32 input2txid, bytes32 expectedTxid);

    /// @notice Thrown when the number of inputs in a challenge transaction is incorrect
    /// @param actual The actual number of inputs found
    /// @param expected The expected number of inputs
    error InvalidChallengeInputCount(uint256 actual, uint256 expected);

    /// @notice Thrown when the number of inputs in an input not revealed transaction is incorrect
    /// @param actual The actual number of inputs found
    /// @param expected The expected number of inputs
    error InvalidInputNotRevealedInputCount(uint256 actual, uint256 expected);

    /// @notice Thrown when the number of outputs in an input not revealed transaction is incorrect
    /// @param actual The actual number of outputs found
    /// @param expected The expected number of outputs (1 OP_RETURN + one speedup per committee member)
    error InvalidInputNotRevealedOutputCount(uint256 actual, uint256 expected);

    /// @notice Thrown when outputs are empty or output 0 of input not revealed tx is not OP_RETURN as required
    error InvalidInputNotRevealedOutput();

    /// @notice Thrown when outputs are empty or the output 0 input revealed tx is actually the output 0 of an input not revealed tx
    error InvalidRevealedOutput();

    /// @notice Thrown when the number of inputs in a input reveal transaction is incorrect
    /// @param actual The actual number of inputs found
    /// @param expected The expected number of inputs
    error InvalidRevealedInputCount(uint256 actual, uint256 expected);

    /// @notice Thrown when the number of outputs in an input reveal transaction is incorrect
    /// @param actual The actual number of outputs found
    /// @param expected The expected number of outputs
    error InvalidRevealedOutputCount(uint256 actual, uint256 expected);

    /// @notice Thrown when there is no challenge registered for the given accept peg-in transaction id
    /// @param acceptPeginTxid The accept peg-in transaction id
    error NoChallengeRegistered(bytes32 acceptPeginTxid);

    /// @notice Thrown when the stop operator won transaction id is invalid
    /// @param txid The invalid transaction id
    error InvalidStopOperatorWonTxid(bytes32 txid);

    /// @notice Thrown when the number of inputs in a stop operator won transaction is incorrect
    /// @param actual The actual number of inputs found
    /// @param expected The expected number of inputs
    error InvalidStopOperatorWonInputCount(uint256 actual, uint256 expected);
}
