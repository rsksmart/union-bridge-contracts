// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {CommitteeRegistry} from "src/CommitteeRegistry.sol";
import {ScriptUtils} from "script/helpers/ScriptUtils.sol";

contract SetCommitteeMinMembersScript is ScriptUtils {
    CommitteeRegistry committeeRegistry;
    uint256 minMembers;

    function setUp() internal {
        // ====== Arguments ======
        minMembers = 10;
        committeeRegistry = CommitteeRegistry(payable(0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0));
    }

    function run() public {
        setUp();

        vm.startBroadcast(getDeployerKey());
        committeeRegistry.setCommitteeMinMembers(minMembers);
        vm.stopBroadcast();

        console.log("=== value after setCommitteeMinMembers ===");
        console.log(committeeRegistry.minCommitteeMembers());
    }
}
