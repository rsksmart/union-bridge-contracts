// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {BtcTxSPVProof} from "./IPegCommonTypes.sol";
import {StreamPosition} from "./IPegCommonTypes.sol";

/// @notice Temporary information stored during challenge processing
/// @dev Contains data needed for challenge transaction validation
struct ChallengeTempInfo {
    /// @notice The transaction id of the challenge transaction
    bytes32 challengeTxid;
    /// @notice The transaction id of the input reveal transaction
    bytes32 revealTxid;
}

/// @title IChallengeManager
/// @notice Interface for managing challenge operations
interface IChallengeManager {
    /// @notice Gets the temporary challenge information for a given accept peg-in transaction id
    /// @param _acceptPeginTxid The accept peg-in transaction id
    /// @return The temporary challenge information
    function getChallengeTempInfo(bytes32 _acceptPeginTxid) external view returns (ChallengeTempInfo memory);

    /// @notice Registers a challenge for a peg-out transaction
    /// @dev Validates the SPV proof and updates the peg-out status accordingly
    /// @param _acceptPeginTxid The accept peg-in transaction id that is being challenged
    /// @param _challenge The BTC SPV proof of the challenge transaction
    function registerChallenge(bytes32 _acceptPeginTxid, BtcTxSPVProof calldata _challenge) external;

    /// @notice Registers an input revealed for a challenge transaction
    /// @dev Validates the SPV proof and updates the challenge status accordingly
    /// @param _acceptPeginTxid The accept peg-in transaction id that is being revealed
    /// @param _inputRevealed The BTC SPV proof of the input revealed transaction
    function registerInputRevealed(bytes32 _acceptPeginTxid, BtcTxSPVProof memory _inputRevealed) external;

    // ===================== Events =====================
    /// @notice Event emitted when a challenge is registered for a peg-out
    /// @param txid The hash of the challenge transaction
    /// @param acceptPeginTxid The hash of the original accept peg-in transaction
    /// @param committeeId The ID of the committee responsible for this challenge
    /// @param streamInfo The stream position information related to this challenge
    event ChallengeRegistered(
        bytes32 indexed txid, bytes32 indexed acceptPeginTxid, uint128 committeeId, StreamPosition streamInfo
    );

    /// @notice Event emitted when an input is revealed for a challenge
    /// @param txid The hash of the reveal transaction
    /// @param acceptPeginTxid The hash of the original accept peg-in transaction
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

    /// @notice Thrown when the number of inputs in a challenge transaction is incorrect
    /// @param actual The actual number of inputs found
    /// @param expected The expected number of inputs
    error InvalidChallengeInputCount(uint256 actual, uint256 expected);

    /// @notice Thrown when the number of inputs in a input reveal transaction is incorrect
    /// @param actual The actual number of inputs found
    /// @param expected The expected number of inputs
    error InvalidRevealedInputCount(uint256 actual, uint256 expected);
}
