// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {DeployImplAndProxy, DeployedContracts} from "script/deploy/01_DeployImplAndProxy.s.sol";
import {RSK_BRIDGE_ADDRESS} from "src/interfaces/IBridge.sol";
import {BtcNetwork, ChainIds} from "src/libraries/Network.sol";
import {HelperContract} from "test/helpers/HelperContract.sol";

contract DeployImplAndProxyTest is HelperContract {
    function test_Run_RskRegtestUsesNativeBridge() external {
        vm.chainId(ChainIds.RSK_REGTEST);

        DeployImplAndProxy deploy = new DeployImplAndProxy();
        DeployedContracts memory deployed = deploy.run();

        assertEq(address(deployed.bridgeAddress), address(RSK_BRIDGE_ADDRESS));
        assertEq(address(deployed.rbtcBridge.bridge()), address(RSK_BRIDGE_ADDRESS));
        assertEq(uint256(deployed.bitcoinManager.network()), uint256(BtcNetwork.REGTEST));
    }
}
