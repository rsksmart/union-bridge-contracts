// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

/// @title Pausable
/// @notice Base contract that provides pause/unpause functionality with a dedicated pauser role
/// @dev Inherits from OpenZeppelin's PausableUpgradeable and adds a pauser role
abstract contract Pausable is PausableUpgradeable {
    /// @notice The address that can pause and unpause the contract
    address public pauser;

    /// @notice Pauses the contract
    /// @dev Only callable by the pauser
    function pause() external virtual onlyPauser {
        _pause();
    }

    /// @notice Unpauses the contract
    /// @dev Only callable by the pauser
    function unpause() external virtual onlyPauser {
        _unpause();
    }

    /// @notice Modifier to restrict access to the Pauser
    /// @dev Reverts if the caller is not the Pauser
    modifier onlyPauser() {
        _onlyPauser(msg.sender);
        _;
    }

    /// @notice Internal function to check if an account is the pauser
    /// @param _account The account to check
    /// @dev Reverts with UnauthorizedAccount if the account is not the pauser
    function _onlyPauser(address _account) internal view virtual {
        if (pauser != _account) {
            revert UnauthorizedAccount(_account);
        }
    }

    /// @notice Error thrown when an account is not authorized
    /// @param account The unauthorized account
    error UnauthorizedAccount(address account);
}
