// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC1967Utils, UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {Ownable2StepUpgradeable} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";

/// @title Base Proxy
/// @notice Abstract base contract for upgradeable proxy contracts
/// @dev Provides UUPS upgradeability and ownership functionality
/// @dev Inherits from OpenZeppelin's UUPSUpgradeable and Ownable2StepUpgradeable
abstract contract BaseProxy is UUPSUpgradeable, Ownable2StepUpgradeable {
    /* ========== CONSTRUCTOR ========== */
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the BaseProxy contract
    /// @dev Sets up the initial owner for the contract
    /// @dev Can only be called once during contract deployment
    /// @param _initialOwner The address that will be set as the initial owner
    function __BaseProxy_init(address _initialOwner) public initializer {
        // Validaton that the initial owner is not zero address is done in Ownable2StepUpgradeable
        __Ownable_init_unchained(_initialOwner);
    }

    /* ========== UUPS ========== */
    //solhint-disable-next-line no-empty-blocks
    function _authorizeUpgrade(address) internal override onlyOwner {}

    /// @notice Gets the current implementation address of the proxy
    /// @dev Returns the address of the implementation contract behind the proxy
    /// @return The address of the current implementation contract
    function getImplementation() external view returns (address) {
        return ERC1967Utils.getImplementation();
    }
}
