// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

/// @notice Interface for access control in the union bridge
/// @dev This interface provides error definitions for access control operations
/// @dev Used to ensure proper authorization for sensitive operations
interface IAccessManager {
    /// @notice Requires the caller to have permissions to modify the peg status
    /// @param _caller The address of the caller
    /// @dev Reverts if the caller does not have permissions to modify the peg status
    function canModifyPegStatus(address _caller) external view;

    /// @notice Requires the caller to have permissions to create a committee
    /// @param _caller The address of the caller
    /// @dev Reverts if the caller does not have permissions to create a committee
    function canCreateCommittee(address _caller) external view;

    /// @notice Requires the caller to have permissions to select a take operator
    /// @param _caller The address of the caller
    /// @dev Reverts if the caller does not have permissions to select a take operator
    function canSelectTakeOperator(address _caller) external view;

    /// @notice Requires the caller to have permissions to release a committee
    /// @param _caller The address of the caller
    /// @dev Reverts if the caller does not have permissions to release a committee
    function canReleaseCommittee(address _caller) external view;

    /// @notice Requires the caller to have permissions to create a packet
    /// @param _caller The address of the caller
    /// @dev Reverts if the caller does not have permissions to create a packet
    function canCreatePacket(address _caller) external view;

    /// @notice Requires the caller to have permissions to mint RBTC
    /// @param _caller The address of the caller
    /// @dev Reverts if the caller does not have permissions to mint RBTC
    function canMintRbtc(address _caller) external view;

    /// @notice Requires the caller to have permissions to burn RBTC
    /// @param _caller The address of the caller
    /// @dev Reverts if the caller does not have permissions to burn RBTC
    function canBurnRbtc(address _caller) external view;

    /// @notice Requires the caller to have permissions to initialize signatures
    /// @param _caller The address of the caller
    /// @dev Reverts if the caller does not have permissions to initialize signatures
    function canInitSignatures(address _caller) external view;

    /// @notice Requires the caller to have permissions to initialize operator take txids
    /// @param _caller The address of the caller
    /// @dev Reverts if the caller does not have permissions to initialize operator take txids
    function canInitOperatorTakeTxids(address _caller) external view;

    /// @notice Requires the caller to have permissions to modify candidates for a stream
    /// @param _caller The address of the caller
    /// @dev Reverts if the caller does not have permissions to modify candidates for a stream
    function canModifyCandidatesForStream(address _caller) external view;

    /// @notice Requires the caller to have permissions to set the base event
    /// @param _caller The address of the caller
    /// @dev Reverts if the caller does not have permissions to set the base event
    function canSetBaseEvent(address _caller) external view;

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

    /// @notice Thrown when an account is not authorized to set the base event
    /// @param _caller The address of the unauthorized account
    error UnauthorizedToSetBaseEvent(address _caller);

    // --- TESTNET ONLY ---
    // TODO: Remove before mainnet deployment
    /// @notice Reverts if not called on testnet, regtest, or local network
    /// @dev Used to protect testnet-only functions from being called on mainnet
    function revertIfNotTestnet() external view;

    /// @notice Thrown when a testnet-only function is called on mainnet
    error TestnetOnlyFunction();

    // --- END TESTNET ONLY ---
}
