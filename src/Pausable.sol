// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {IPausable} from "./interfaces/IPausable.sol";

/// @title Pausable
/// @notice Base contract that provides pause/unpause functionality with a dedicated pauser role
/// @dev Inherits from OpenZeppelin's PausableUpgradeable and adds a pauser role
contract Pausable is IPausable, PausableUpgradeable {
    /// @notice The address that can pause and unpause the contract
    address public pauser;

    /* ========== CONSTRUCTOR ========== */
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the Pausable contract
    /// @dev Can only be called once during contract deployment
    function __Pauser_init() internal initializer {
        __Pausable_init_unchained();
    }

    /// @notice Modifier to restrict access to the Pausable
    /// @dev Reverts if the caller is not the Pauser
    modifier onlyPauser() {
        _onlyPauser(_msgSender());
        _;
    }

    /// @notice Pauses the contract
    /// @dev Only callable by the pausable
    function pause() external onlyPauser {
        _pause();
    }

    /// @notice Unpauses the contract
    /// @dev Only callable by the pausable
    function unpause() external onlyPauser {
        _unpause();
    }

    /// @notice Returns true if the contract is paused, and false otherwise.
    /// @dev Returns true if the contract is paused, and false otherwise.
    function isPaused() public view returns (bool) {
        return paused();
    }

    /// @notice Internal function to check if an account is the pauser
    /// @param _account The account to check
    /// @dev Reverts with UnauthorizedAccount if the account is not the pausable
    function _onlyPauser(address _account) internal view virtual {
        if (pauser != _account) {
            revert UnauthorizedAccount(_account);
        }
    }

    /// @notice Error thrown when an account is not authorized
    /// @param account The unauthorized account
    error UnauthorizedAccount(address account);
}
