// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {console} from "forge-std/console.sol";
import {BridgeMock} from "test/helpers/BridgeMock.sol";
import {ScriptUtils} from "script/helpers/ScriptUtils.sol";
import {ContractAddressManager} from "script/helpers/ContractAddressManager.sol";

contract SetMockBridgeConfirmationsScript is ScriptUtils, ContractAddressManager {
    BridgeMock bridgeMock;
    int256 confirmations;

    function setUp() internal {
        // ====== Arguments ======
        confirmations = -1;
        bridgeMock = BridgeMock(getBridge());
    }

    function run() public {
        setUp();

        vm.startBroadcast(getDeployerKey());
        bridgeMock.setBtcTransactionConfirmations(confirmations);
        vm.stopBroadcast();

        console.log("=== setBtcTransactionConfirmations ===");
        console.log(
            bridgeMock.getBtcTransactionConfirmations(
                0x0000000000000000000000000000000000000000000000000000000000000000,
                0x0000000000000000000000000000000000000000000000000000000000000000,
                0,
                new bytes32[](0)
            )
        );
    }
}
