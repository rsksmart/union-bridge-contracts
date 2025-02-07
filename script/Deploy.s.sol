// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {StreamDenomination, Role, CommitteeMember, Committee, CommitteeRegistry} from "src/CommitteeRegistry.sol";
import {console} from "forge-std/Script.sol";
import {BaseDeploy} from "./BaseDeploy.s.sol";
import {BitcoinManager} from "src/BitcoinManager.sol";
import {PegManager} from "src/PegManager.sol";
import {HelperContract} from "test/helpers/HelperContract.sol";

struct CommitteeDeploymentParams {
    Committee committee;
    bytes32[] committeeMembers;
}

contract DeployScript is BaseDeploy, HelperContract {
    /// @notice Deployment parameters for each chain
    /// from https://github.com/defi-wonderland/solidity-foundry-boilerplate/blob/main/script/Deploy.sol
    CommitteeDeploymentParams public committeeDeploymentParams;
    // Contracts to be deployed
    CommitteeRegistry public committeeRegistry; // TODO unify with the one in HelperContract
    PegManager public pegManager; // TODO unify with the one in HelperContract

    function setUp() public {
        CommitteeMember[] memory members = new CommitteeMember[](2);
        members[0] = CommitteeMember({index: 0, role: Role.Operator});
        members[1] = CommitteeMember({index: 1, role: Role.Operator});

        // RSK Mainnet
        if (block.chainid == 30) {
            committeeDeploymentParams.committee.internalKey =
                0x0908421cb37d204b0c68660d093534d50d01fa791a3313e5fd9c21da137785eb;
            committeeDeploymentParams.committee.memberIndexesAndRoles.push(members[0]);
            committeeDeploymentParams.committee.memberIndexesAndRoles.push(members[1]);
            committeeDeploymentParams.committee.leaderIndex = 0;
            committeeDeploymentParams.committeeMembers.push(generatePubKey(0));
            committeeDeploymentParams.committeeMembers.push(generatePubKey(1));
        } else if (block.chainid == 31) {
            // RSK Testnet
            committeeDeploymentParams.committee = Committee({
                internalKey: 0x0908421cb37d204b0c68660d093534d50d01fa791a3313e5fd9c21da137785eb,
                leader: vm.addr(1),
                backupLeader: vm.addr(2)
            });
            committeeDeploymentParams.committeeMembers.push(vm.addr(1));
            committeeDeploymentParams.committeeMembers.push(vm.addr(2));
        } else if (block.chainid == 31337 || block.chainid == 1337) {
            // Foundry local chainid
            committeeDeploymentParams.committee.internalKey =
                0x0908421cb37d204b0c68660d093534d50d01fa791a3313e5fd9c21da137785eb;
            committeeDeploymentParams.committee.memberIndexesAndRoles.push(members[0]);
            committeeDeploymentParams.committee.memberIndexesAndRoles.push(members[1]);
            committeeDeploymentParams.committee.leaderIndex = 0;
            committeeDeploymentParams.committeeMembers.push(generatePubKey(0));
            committeeDeploymentParams.committeeMembers.push(generatePubKey(1));
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

        StreamDenomination[] memory streams = new StreamDenomination[](1);
        streams[0] = StreamDenomination._0_001BTC;
        Role[] memory roles = new Role[](1);
        roles[0] = Role.Operator;
        committeeRegistry.registerMember(committeeDeploymentParams.committeeMembers[0], streams, roles);
        committeeRegistry.registerMember(committeeDeploymentParams.committeeMembers[1], streams, roles);
        committeeRegistry.registerCommittee(committeeDeploymentParams.committee);

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
