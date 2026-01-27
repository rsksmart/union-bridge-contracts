// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

/// @notice Interface for access control in the union bridge
/// @dev This interface provides error definitions for access control operations
/// @dev Used to ensure proper authorization for sensitive operations
interface IAccessManager {
    /// @notice Requires the caller to have permissions to modify the peg status
    /// @param _caller The address of the caller
    /// @dev Reverts if the caller does not have permissions to modify the peg status
    function requireCanModifyPegStatus(address _caller) external view;

    /// @notice Requires the caller to have permissions to create a committee
    /// @param _caller The address of the caller
    /// @dev Reverts if the caller does not have permissions to create a committee
    function requireCanCreateCommittee(address _caller) external view;

    /// @notice Requires the caller to have permissions to select a take operator
    /// @param _caller The address of the caller
    /// @dev Reverts if the caller does not have permissions to select a take operator
    function requireCanSelectTakeOperator(address _caller) external view;

    /// @notice Requires the caller to have permissions to release a committee
    /// @param _caller The address of the caller
    /// @dev Reverts if the caller does not have permissions to release a committee
    function requireCanReleaseCommittee(address _caller) external view;

    /// @notice Requires the caller to have permissions to create a packet
    /// @param _caller The address of the caller
    /// @dev Reverts if the caller does not have permissions to create a packet
    function requireCanCreatePacket(address _caller) external view;

    /// @notice Requires the caller to have permissions to mint RBTC
    /// @param _caller The address of the caller
    /// @dev Reverts if the caller does not have permissions to mint RBTC
    function requireCanMintRbtc(address _caller) external view;

    /// @notice Requires the caller to have permissions to burn RBTC
    /// @param _caller The address of the caller
    /// @dev Reverts if the caller does not have permissions to burn RBTC
    function requireCanBurnRbtc(address _caller) external view;

    /// @notice Requires the caller to have permissions to initialize signatures
    /// @param _caller The address of the caller
    /// @dev Reverts if the caller does not have permissions to initialize signatures
    function requireCanInitSignatures(address _caller) external view;

    /// @notice Requires the caller to have permissions to initialize operator take txids
    /// @param _caller The address of the caller
    /// @dev Reverts if the caller does not have permissions to initialize operator take txids
    function requireCanInitOperatorTakeTxids(address _caller) external view;

    /// @notice Requires the caller to have permissions to modify candidates for a stream
    /// @param _caller The address of the caller
    /// @dev Reverts if the caller does not have permissions to modify candidates for a stream
    function requireCanModifyCandidatesForStream(address _caller) external view;

    // ===================== Events =====================

    // ===================== Errors =====================

    /// @notice Thrown when an account is not authorized to create a committee
    /// @param _caller The address of the unauthorized account
    error UnauthorizedToCreateCommittee(address _caller);

    /// @notice Thrown when an account is not authorized to release a committee
    /// @param _caller The address of the unauthorized account
    error UnauthorizedToReleaseCommittee(address _caller);

    /// @notice Thrown when an account is not authorized to select a take operator
    /// @param _caller The address of the unauthorized account
    error UnauthorizedToSelectTakeOperator(address _caller);

    /// @notice Thrown when an account is not authorized to modify the peg status
    /// @param _caller The address of the unauthorized account
    error UnauthorizedToModifyPegStatus(address _caller);

    /// @notice Thrown when an account is not authorized to create a packet
    /// @param _caller The address of the unauthorized account
    error UnauthorizedToCreatePacket(address _caller);

    /// @notice Thrown when an account is not authorized to mint RBTC
    /// @param _caller The address of the unauthorized account
    error UnauthorizedToMintRbtc(address _caller);

    /// @notice Thrown when an account is not authorized to burn RBTC
    /// @param _caller The address of the unauthorized account
    error UnauthorizedToBurnRbtc(address _caller);

    /// @notice Thrown when an account is not authorized to initialize signatures
    /// @param _caller The address of the unauthorized account
    error UnauthorizedToInitSignatures(address _caller);

    /// @notice Thrown when an account is not authorized to initialize operator take txids
    /// @param _caller The address of the unauthorized account
    error UnauthorizedToInitOperatorTakeTxids(address _caller);

    /// @notice Thrown when an account is not authorized to modify candidates for a stream
    /// @param _caller The address of the unauthorized account
    error UnauthorizedToModifyCandidatesForStream(address _caller);
}
