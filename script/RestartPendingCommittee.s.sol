// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {console} from "forge-std/console.sol";
import {PegManager} from "src/PegManager.sol";
import {ScriptUtils} from "script/helpers/ScriptUtils.sol";
import {ICommitteeRegistry} from "src/interfaces/ICommitteeRegistry.sol";
import {Vm} from "forge-std/Vm.sol";

contract RestartPendingCommitteeScript is ScriptUtils {
    PegManager pegManager;
    ICommitteeRegistry committeeRegistry;
    uint64 streamId;

    function setUp() internal {
        // ====== Arguments ======
        pegManager = getPegManagerAddress();
        committeeRegistry = pegManager.committeeRegistry();
        streamId = 1;
    }

    function run() public {
        setUp();

        uint256 createdAt = committeeRegistry.getPendingCommittee(streamId).createdAt;

        console.log("=== Restart Pending Committee ===");
        vm.recordLogs();

        vm.startBroadcast(getDeployerKey());
        // FIXME: This script is not tested yet.
        committeeRegistry.restartPendingCommittee(streamId);
        vm.stopBroadcast();

        uint256 createdAtNewCommittee = committeeRegistry.getPendingCommittee(streamId).createdAt;
        if (createdAtNewCommittee > createdAt) {
            console.log("Pending committee restarted successfully.");
        } else {
            revert("Failed to restart pending committee.");
        }

        Vm.Log[] memory logs = vm.getRecordedLogs();
        for (uint256 i = 0; i < logs.length; i++) {
            Vm.Log memory log = logs[i];
            console.log("Log: %d", i);
            console.logBytes32(log.topics[0]);
            console.logBytes(log.data);
        }
    }
}
