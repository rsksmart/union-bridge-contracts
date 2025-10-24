// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {console} from "forge-std/console.sol";
import {ICommitteeRegistry} from "src/interfaces/ICommitteeRegistry.sol";
import {ScriptUtils} from "script/helpers/ScriptUtils.sol";
import {PegManager} from "src/PegManager.sol";

contract SetCommitteeMinWatchtowersScript is ScriptUtils {
    ICommitteeRegistry committeeRegistry;
    uint256 minWatchtowers;

    function setUp() internal {
        // ====== Arguments ======
        minWatchtowers = 3;
        PegManager pegManager = getPegManagerAddress();
        committeeRegistry = pegManager.committeeRegistry();
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
