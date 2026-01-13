// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {console} from "forge-std/console.sol";
import {BridgeMock} from "test/helpers/BridgeMock.sol";
import {ScriptUtils} from "script/helpers/ScriptUtils.sol";
import {ContractAddressManager} from "script/helpers/ContractAddressManager.sol";

contract AdvanceBitcoinBlocksScript is ScriptUtils, ContractAddressManager {
    BridgeMock bridgeMock;

    function setUp() internal {
        bridgeMock = BridgeMock(payable(address(getBridge())));
    }

    function run(int256 _blocksToAdvance) public {
        setUp();

        // Get the current block height
        int256 currentHeight = bridgeMock.getBtcBlockchainBestChainHeight();
        int256 newHeight = currentHeight + _blocksToAdvance;

        console.log("=== Advancing Bitcoin Blocks ===");
        console.log("Current height:");
        console.logInt(currentHeight);
        console.log("Blocks to advance:");
        console.logInt(_blocksToAdvance);
        console.log("New height:");
        console.logInt(newHeight);

        vm.startBroadcast(getDeployerKey());
        bridgeMock.setBtcBlockchainBestChainHeight(newHeight);
        vm.stopBroadcast();

        console.log("=== Bitcoin blocks advanced successfully ===");
    }
}
