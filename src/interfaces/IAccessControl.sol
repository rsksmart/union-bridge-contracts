// SPDX-License-Identifier: UNKNOWN
pragma solidity ^0.8.20;

/// @notice Interface for access control in the union bridge
/// @dev This interface provides error definitions for access control operations
/// @dev Used to ensure proper authorization for sensitive operations
interface IAccessControl {
    /// @notice Thrown when the Peg Manager address is set to zero
    error PegManagerAddressZero();

    /// @notice Thrown when an account is not authorized to perform an operation
    /// @param sender The address of the unauthorized account
    error UnauthorizedAccount(address sender);
}
