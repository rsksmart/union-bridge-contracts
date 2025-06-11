// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {CommitteeRegistry} from "src/CommitteeRegistry.sol";
import {ScriptUtils} from "script/helpers/ScriptUtils.sol";

contract SetPendingCommitteeTimeoutScript is ScriptUtils {
    CommitteeRegistry committeeRegistry;
    uint256 timeout;

    function setUp() internal {
        // ====== Arguments ======
        timeout = 1000;
        committeeRegistry = CommitteeRegistry(payable(0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0));
    }

    function run() public {
        setUp();

        vm.startBroadcast(getDeployerKey());
        committeeRegistry.setPendingCommitteeTimeout(timeout);
        vm.stopBroadcast();

        console.log("=== value after setPendingCommitteeTimeout ===");
        console.log(committeeRegistry.pendingCommitteeTimeout());
    }
}
