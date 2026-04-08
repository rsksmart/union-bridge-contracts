// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Interface for pauser in the union bridge
/// @dev This interface provides error definitions for pauser operations
/// @dev Used to implement open zeppelin's pauser functionality
interface IPausable {
    /// @notice Pauses the contract
    /// @dev Only callable by the pauser
    function pause() external;

    /// @notice Unpauses the contract
    /// @dev Only callable by the pauser
    function unpause() external;

    /// @notice Returns true if the contract is paused, and false otherwise.
    function isPaused() external view returns (bool);

    // ===================== Events =====================

    /// @notice Event emitted when the pauser is updated
    /// @param newPauser The new pauser address
    event PauserUpdated(address newPauser);

    // ===================== Errors =====================

    /// @notice Thrown when an address is zero
    error InvalidZeroAddress();

    /// @notice Error thrown when an account is not authorized as pauser
    /// @param account The unauthorized account
    error UnauthorizedPauser(address account);
}
