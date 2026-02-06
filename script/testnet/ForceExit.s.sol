// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {console} from "forge-std/console.sol";
import {ScriptUtils} from "script/helpers/ScriptUtils.sol";
import {ContractAddressManager} from "script/helpers/ContractAddressManager.sol";
import {ChainIds} from "src/libraries/Network.sol";
import {IMemberRegistry} from "src/interfaces/IMemberRegistry.sol";

contract ForceExitScript is ScriptUtils, ContractAddressManager {
    IMemberRegistry memberRegistry;

    function setUp() internal {
        memberRegistry = getMemberRegistry();
    }

    function run(address _to) public {
        setUp();

        console.log("=== Force Exit for TESTING only ===");
        console.log("To:", _to);
        console.log("Contract balance:", address(memberRegistry).balance);

        if (block.chainid == ChainIds.RSK_MAINNET) {
            revert("This function is only for testing purposes");
        }

        console.log("Force exiting contract balance to:", _to);
        vm.startBroadcast(getDeployerKey());
        memberRegistry.forceExit_TESTNET(_to);
        vm.stopBroadcast();
        console.log("Force exit completed");
        console.log("--------------------------------");
    }
}
