// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {console} from "forge-std/console.sol";
import {ICommitteeRegistry} from "src/interfaces/ICommitteeRegistry.sol";
import {ScriptUtils} from "script/helpers/ScriptUtils.sol";
import {PegManager} from "src/PegManager.sol";

contract SetPendingCommitteeTimeoutScript is ScriptUtils {
    ICommitteeRegistry committeeRegistry;
    uint256 timeout;

    function setUp() internal {
        // ====== Arguments ======
        timeout = 1000;
        PegManager pegManager = getPegManagerAddress();
        committeeRegistry = pegManager.committeeRegistry();
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
