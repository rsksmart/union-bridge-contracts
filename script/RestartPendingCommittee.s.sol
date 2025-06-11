// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {PegManager} from "src/PegManager.sol";
import {ChainIds} from "src/libraries/Network.sol";
import {BtcHelper} from "src/libraries/BtcHelper.sol";
import {ScriptUtils} from "script/helpers/ScriptUtils.sol";
import {Slot, Stream, Packet, SlotState, IStreamManager} from "src/interfaces/IStreamManager.sol";
import {CommitteeRegistry} from "src/CommitteeRegistry.sol";
import {Vm} from "forge-std/Vm.sol";

contract RegisterPegoutRequestScript is ScriptUtils {
    PegManager pegManager;
    CommitteeRegistry committeeRegistry;
    uint64 streamId;

    function setUp() internal {
        // ====== Arguments ======
        pegManager = PegManager(0x0165878A594ca255338adfa4d48449f69242Eb8F);
        committeeRegistry = CommitteeRegistry(0xA1B3C2D4f5e6F7a8B9C0d1E2f3a4b5c6D7e8f9A0);
        streamId = 1;
    }

    function run() public {
        setUp();

        (, uint256 createdAt,) = committeeRegistry.getPendingCommittee(streamId);

        console.log("=== Restart Pending Committee ===");
        vm.recordLogs();

        vm.startBroadcast(getDeployerKey());
        // FIXME: This script is not tested yet.
        committeeRegistry.restartPendingCommittee(streamId);
        vm.stopBroadcast();

        (, uint256 createdAtNewCommittee,) = committeeRegistry.getPendingCommittee(streamId);
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
