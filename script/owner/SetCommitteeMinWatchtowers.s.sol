// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {console} from "forge-std/console.sol";
import {CommitteeRegistry} from "src/CommitteeRegistry.sol";
import {ScriptUtils} from "script/helpers/ScriptUtils.sol";

contract SetCommitteeMinWatchtowersScript is ScriptUtils {
    CommitteeRegistry committeeRegistry;
    uint256 minWatchtowers;

    function setUp() internal {
        // ====== Arguments ======
        minWatchtowers = 3;
        committeeRegistry = CommitteeRegistry(payable(0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0));
    }

    function run() public {
        setUp();

        vm.startBroadcast(getDeployerKey());
        committeeRegistry.setCommitteeMinWatchtowers(minWatchtowers);
        vm.stopBroadcast();

        console.log("=== value after setCommitteeMinWatchtowers ===");
        console.log(committeeRegistry.minCommitteeWatchtowers());
    }
}
