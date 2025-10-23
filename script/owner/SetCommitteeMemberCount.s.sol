// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {console} from "forge-std/console.sol";
import {ICommitteeRegistry} from "src/interfaces/ICommitteeRegistry.sol";
import {ScriptUtils} from "script/helpers/ScriptUtils.sol";
import {PegManager} from "src/PegManager.sol";

contract SetcommitteeMemberCountScript is ScriptUtils {
    ICommitteeRegistry committeeRegistry;
    uint256 committeeMemberCount;

    function setUp() internal {
        // ====== Arguments ======
        PegManager pegManager = getPegManagerAddress();
        committeeRegistry = pegManager.committeeRegistry();
        committeeMemberCount = 10;
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
