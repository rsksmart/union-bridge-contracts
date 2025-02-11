// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {StreamDenomination, Role, CommitteeMember, Committee, CommitteeRegistry} from "src/CommitteeRegistry.sol";
import {BitcoinManager} from "src/BitcoinManager.sol";
import {PegManager} from "src/PegManager.sol";

struct CommitteeDeploymentParams {
    Committee committee;
    bytes32[] committeeMembers;
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
        CommitteeMember[] memory members = new CommitteeMember[](2);
        members[0] = CommitteeMember({index: 0, role: Role.Operator});
        members[1] = CommitteeMember({index: 1, role: Role.Operator});

        // RSK Mainnet
        if (block.chainid == 30) {
            committeeDeploymentParams.committee.internalKey =
                0x0908421cb37d204b0c68660d093534d50d01fa791a3313e5fd9c21da137785eb;
            committeeDeploymentParams.committee.memberIndicesAndRoles.push(members[0]);
            committeeDeploymentParams.committee.memberIndicesAndRoles.push(members[1]);
            committeeDeploymentParams.committee.leaderIndex = 0;
            committeeDeploymentParams.committeeMembers.push(bytes32(uint256(1)));
            committeeDeploymentParams.committeeMembers.push(bytes32(uint256(2)));
        } else if (block.chainid == 31) {
            // RSK Testnet or
            // Foundry local chainid
            committeeDeploymentParams.committee.internalKey =
                0x0908421cb37d204b0c68660d093534d50d01fa791a3313e5fd9c21da137785eb;
            committeeDeploymentParams.committee.memberIndicesAndRoles.push(members[0]);
            committeeDeploymentParams.committee.memberIndicesAndRoles.push(members[1]);
            committeeDeploymentParams.committee.leaderIndex = 0;
            committeeDeploymentParams.committeeMembers.push(bytes32(uint256(1)));
            committeeDeploymentParams.committeeMembers.push(bytes32(uint256(2)));
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
