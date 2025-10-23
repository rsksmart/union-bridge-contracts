// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {console} from "forge-std/console.sol";
import {ICommitteeRegistry} from "src/interfaces/ICommitteeRegistry.sol";
import {ScriptUtils} from "script/helpers/ScriptUtils.sol";
import {PegManager} from "src/PegManager.sol";

contract SetCommitteeMinOperatorsScript is ScriptUtils {
    ICommitteeRegistry committeeRegistry;
    uint256 minOperators;

    function setUp() internal {
        // ====== Arguments ======
        minOperators = 3;
        PegManager pegManager = getPegManagerAddress();
        committeeRegistry = pegManager.committeeRegistry();
    }

    function run() public {
        setUp();

        vm.startBroadcast(getDeployerKey());
        committeeRegistry.setCommitteeMinOperators(minOperators);
        vm.stopBroadcast();

        console.log("=== value after setCommitteeMinOperators ===");
        console.log(committeeRegistry.minCommitteeOperators());
    }
}
