// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {BaseProxy} from "./BaseProxy.sol";
import {IAccessControl} from "./interfaces/IAccessControl.sol";
/// @title Access Control
/// @notice Manages access control for the union bridge system
/// @dev Provides role-based access control with PeginManager and PegoutManager as the primary authorized accounts
/// @dev Inherits from IAccessControl and BaseProxy for interface compliance and proxy functionality

contract AccessControl is IAccessControl, BaseProxy {
    /// @notice The address of the PeginManager contract that has administrative privileges
    /// @dev This address is authorized to call protected functions in contracts that inherit from AccessControl
    address public peginManager;

    /// @notice The address of the PegoutManager contract that has administrative privileges
    /// @dev This address is authorized to call protected functions in contracts that inherit from AccessControl
    address public pegoutManager;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the AccessControl contract
    /// @dev Sets up the initial owner and PeginManager/PegoutManager addresses
    /// @dev Can only be called once during contract deployment
    /// @param _initialOwner The address that will be set as the initial owner
    /// @param _peginManager The address of the PeginManager contract
    /// @param _pegoutManager The address of the PegoutManager contract
    function __AccessControl_init(address _initialOwner, address _peginManager, address _pegoutManager)
        public
        initializer
    {
        if (_peginManager == address(0)) {
            revert PegManagerAddressZero();
        }
        if (_pegoutManager == address(0)) {
            revert PegManagerAddressZero();
        }
        peginManager = _peginManager;
        pegoutManager = _pegoutManager;
        __BaseProxy_init(_initialOwner);
    }

    /// @notice Initializes the AccessControl contract with delayed peg manager setup
    /// @dev Used when peg managers need to be set after deployment via setters
    /// @dev Can only be called once during contract deployment
    /// @param _initialOwner The address that will be set as the initial owner
    function __AccessControl_init_without_peg_managers(address _initialOwner) internal initializer {
        __BaseProxy_init(_initialOwner);
    }

    /**
     * @dev Throws if the sender is not the peginManager or pegoutManager.
     */
    function _checkPegManager() internal view virtual {
        address sender = _msgSender();
        if (peginManager != sender && pegoutManager != sender) {
            revert UnauthorizedAccount(sender);
        }
    }

    modifier onlyPegManager() {
        _checkPegManager();
        _;
    }
}
