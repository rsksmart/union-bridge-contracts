// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

/// @notice Interface for access control in the union bridge
/// @dev This interface provides error definitions for access control operations
/// @dev Used to ensure proper authorization for sensitive operations
interface IAccessControl {
    /// @notice Thrown when the Pegin Manager address is set to zero
    error PeginManagerAddressZero();

    /// @notice Thrown when the Pegout Manager address is set to zero
    error PegoutManagerAddressZero();

    /// @notice Thrown when an account is not authorized to perform an operation
    /// @param sender The address of the unauthorized account
    error UnauthorizedAccount(address sender);
}
