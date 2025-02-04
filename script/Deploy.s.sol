// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {Committee, CommitteeRegistry} from "src/CommitteeRegistry.sol";
import {BitcoinManager} from "src/BitcoinManager.sol";
import {PegManager} from "src/PegManager.sol";

struct CommitteeDeploymentParams {
    Committee committee;
    address[] committeeMembers;
}

contract Deploy is Script {
    /// @notice Deployment parameters for each chain
    /// from https://github.com/defi-wonderland/solidity-foundry-boilerplate/blob/main/script/Deploy.sol
    CommitteeDeploymentParams internal committeeDeploymentParams;
    // Contracts to be deployed
    CommitteeRegistry public committeeRegistry;
    BitcoinManager public bitcoinManager;
    PegManager public pegManager;

    function setUp() public {
        // RSK Mainnet
        if (block.chainid == 30) {
            committeeDeploymentParams.committee = Committee({
                internalKey: 0x0908421cb37d204b0c68660d093534d50d01fa791a3313e5fd9c21da137785eb,
                leader: vm.addr(1),
                backupLeader: vm.addr(2)
            });
            committeeDeploymentParams.committeeMembers.push(vm.addr(1));
            committeeDeploymentParams.committeeMembers.push(vm.addr(2));
        } else if (block.chainid == 31 || block.chainid == 31337) {
            // RSK Testnet or
            // Foundry local chainid
            committeeDeploymentParams.committee = Committee({
                internalKey: 0x0908421cb37d204b0c68660d093534d50d01fa791a3313e5fd9c21da137785eb,
                leader: vm.addr(1),
                backupLeader: vm.addr(2)
            });
            committeeDeploymentParams.committeeMembers.push(vm.addr(1));
            committeeDeploymentParams.committeeMembers.push(vm.addr(2));
        } else {
            revert("Blockchain is not RSK");
        }
    }

    function run() public {
        deployCommitteeRegistry();
        deployBitcoinManager();
        deployPegManager(committeeRegistry, bitcoinManager);
    }

    function deployCommitteeRegistry() public {
        vm.startBroadcast();

        committeeRegistry = new CommitteeRegistry();
        committeeRegistry.initialize();
        committeeRegistry.registerCommittee(
            committeeDeploymentParams.committee, committeeDeploymentParams.committeeMembers
        );

        vm.stopBroadcast();
    }

    function deployBitcoinManager() public {
        vm.startBroadcast();
        bitcoinManager = new BitcoinManager();
        bitcoinManager.initialize();
        vm.stopBroadcast();
    }

    function deployPegManager(CommitteeRegistry _committeeRegistry, BitcoinManager _bitcoinManager) public {
        vm.startBroadcast();
        pegManager = new PegManager();
        pegManager.initialize(_committeeRegistry, _bitcoinManager);
        vm.stopBroadcast();
    }
}
