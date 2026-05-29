// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {console} from "forge-std/console.sol";
import {CommitteeRegistry} from "src/CommitteeRegistry.sol";
import {ScriptUtils} from "script/helpers/ScriptUtils.sol";

contract SetcommitteeMemberCountScript is ScriptUtils {
    CommitteeRegistry committeeRegistry;
    uint256 committeeMemberCount;

    function setUp() internal {
        // ====== Arguments ======
        committeeMemberCount = 10;
        committeeRegistry = CommitteeRegistry(payable(0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0));
    }

    function run() public {
        setUp();

        vm.startBroadcast(getDeployerKey());
        committeeRegistry.setCommitteeMemberCount(committeeMemberCount);
        vm.stopBroadcast();

        console.log("=== value after setcommitteeMemberCount ===");
        console.log(committeeRegistry.committeeMemberCount());
    }
}
