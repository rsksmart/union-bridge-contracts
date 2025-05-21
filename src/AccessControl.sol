// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {BaseProxy} from "./BaseProxy.sol";
import {IAccessControl} from "./interfaces/IAccessControl.sol";
/// @title Access Control
/// @notice Manages access control

contract AccessControl is IAccessControl, BaseProxy {
    address public pegManager;

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
