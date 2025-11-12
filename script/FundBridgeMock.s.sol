// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {ContractAddressManager} from "script/helpers/ContractAddressManager.sol";
import {ScriptUtils} from "script/helpers/ScriptUtils.sol";

contract FundBridgeMockScript is Script, ContractAddressManager, ScriptUtils {
    function run() public {
        address payable bridgeAddress = getBridge();

        vm.startBroadcast(getDeployerKey());
        // Send RBTC to the bridge from the deployer account
        // Deployer has 10,000 ETH in Anvil by default
        (bool success,) = bridgeAddress.call{value: 400 ether}("");
        require(success, "Failed to fund BridgeMock");
        vm.stopBroadcast();
    }
}
