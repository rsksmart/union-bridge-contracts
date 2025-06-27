// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {BaseProxy} from "./BaseProxy.sol";
import {IAccessControl} from "./interfaces/IAccessControl.sol";
/// @title Access Control
/// @notice Manages access control for the union bridge system
/// @dev Provides role-based access control with PegManager as the primary authorized account
/// @dev Inherits from IAccessControl and BaseProxy for interface compliance and proxy functionality

contract AccessControl is IAccessControl, BaseProxy {
    /// @notice The address of the PegManager contract that has administrative privileges
    /// @dev This address is authorized to call protected functions in contracts that inherit from AccessControl
    address public pegManager;

    /// @notice Initializes the AccessControl contract
    /// @dev Sets up the initial owner and PegManager address
    /// @dev Can only be called once during contract deployment
    /// @param _initialOwner The address that will be set as the initial owner
    /// @param _pegManager The address of the PegManager contract
    function __AccessControl_init(address _initialOwner, address _pegManager) public initializer {
        if (_pegManager == address(0)) {
            revert PegManagerAddressZero();
        }
        pegManager = _pegManager;
        __BaseProxy_init(_initialOwner);
    }

    /**
     * @dev Throws if the sender is not the pegManager.
     */
    function _checkPegManager() internal view virtual {
        if (pegManager != msg.sender) {
            revert UnauthorizedAccount(msg.sender);
        }
    }

    modifier onlyPegManager() {
        _checkPegManager();
        _;
    }
}
