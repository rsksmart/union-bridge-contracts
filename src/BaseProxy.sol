// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {console} from "forge-std/console.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ERC1967Utils} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";

abstract contract BaseProxy is UUPSUpgradeable, OwnableUpgradeable {
    /* ========== CONSTRUCTOR ========== */
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function __BaseProxy_init(address _initialOwner) public initializer {
        __Ownable_init_unchained(_initialOwner);
    }

    /* ========== UUPS ========== */
    //solhint-disable-next-line no-empty-blocks
    function _authorizeUpgrade(address) internal override onlyOwner {}

    function getImplementation() external view returns (address) {
        return ERC1967Utils.getImplementation();
    }
}
