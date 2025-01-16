// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import {PegManager} from "src/PegManager.sol";
import {Committee, CommitteeRegistry} from "src/CommitteeRegistry.sol";
import {BitcoinManager} from "src/BitcoinManager.sol";
import {RSK_BRIDGE_ADDRESS, Bridge} from "src/interfaces/Bridge.sol";

abstract contract HelperContract is Test {
    BitcoinManager bitcoinManager;
    CommitteeRegistry registry;
    bytes32 committee1Key;
    Committee committee1;
    address[] memebersCommittee1;
    bytes32 committee2Key;
    Committee committee2;
    address[] memebersCommittee2;
    bytes32 committee3Key;
    Committee committee3;
    address[] memebersCommittee3;
    PegManager pm;

    function setUpBitcoinManager() internal {
        bitcoinManager = new BitcoinManager();
    }

    function setUpCommittees() internal {
        committee1Key = hex"0908421cb37d204b0c68660d093534d50d01fa791a3313e5fd9c21da137785eb";
        committee1 = Committee({internalKey: committee1Key, leader: vm.addr(1), backupLeader: vm.addr(2)});
        memebersCommittee1 = new address[](2);
        memebersCommittee1[0] = vm.addr(1);
        memebersCommittee1[1] = vm.addr(2);

        committee2Key = hex"1908421cb37d204b0c68660d093534d50d01fa791a3313e5fd9c21da137785ec";
        committee2 = Committee({internalKey: committee2Key, leader: vm.addr(3), backupLeader: vm.addr(4)});
        memebersCommittee2 = new address[](2);
        memebersCommittee2[0] = vm.addr(3);
        memebersCommittee2[1] = vm.addr(4);

        committee3Key = hex"2908421cb37d204b0c68660d093534d50d01fa791a3313e5fd9c21da137785ed";
        committee3 = Committee({internalKey: committee3Key, leader: vm.addr(5), backupLeader: vm.addr(6)});
        memebersCommittee3 = new address[](2);
        memebersCommittee3[0] = vm.addr(5);
        memebersCommittee3[1] = vm.addr(6);
    }

    function setUpCommitteeRegistry() internal {
        setUpCommittees();

        registry = new CommitteeRegistry();
        registry.initialize();

        // Register committees with their mock keys. These are Bitcoin x-only public keys.
        registry.registerCommittee(committee1, memebersCommittee1);
        registry.registerCommittee(committee2, memebersCommittee2);
        registry.registerCommittee(committee3, memebersCommittee3);
    }

    function setUpPegManager() internal {
        setUpBitcoinManager();
        setUpCommitteeRegistry();
        pm = new PegManager();
        pm.initialize(registry, bitcoinManager, Bridge(RSK_BRIDGE_ADDRESS));
    }

    function assertEqCommittee(
        Committee memory actualCommittee,
        Committee memory expectedCommittee,
        string memory testName
    ) internal pure {
        assertEq(
            actualCommittee.internalKey,
            expectedCommittee.internalKey,
            string(abi.encodePacked("expect", testName, "to have  same internalKey"))
        );
        assertEq(
            actualCommittee.leader,
            expectedCommittee.leader,
            string(abi.encodePacked("expect", testName, "to have same leader"))
        );
        assertEq(
            actualCommittee.backupLeader,
            expectedCommittee.backupLeader,
            string(abi.encodePacked("expect", testName, "to have same backupLeader"))
        );
    }

    function assertEqCommitteeMembers(
        address[] memory actualMembers,
        address[] memory expectedMembers,
        string memory testName
    ) internal pure {
        assertEq(
            actualMembers.length,
            expectedMembers.length,
            string(abi.encodePacked("expect", testName, "to have same amount of memebers"))
        );
        for (uint256 i = 0; i < actualMembers.length; i++) {
            assertEq(
                actualMembers[i],
                expectedMembers[i],
                string(abi.encodePacked("expect", testName, " memeber[", Strings.toString(i), "] to have same address"))
            );
        }
    }

    function uintToAddress(uint256 i) internal pure returns (address) {
        return bytes32ToAddress(uintToBytes32(i));
    }

    function bytes32ToAddress(bytes32 word) internal pure returns (address) {
        return address(bytes20(word));
    }

    function uintToBytes32(uint256 i) internal pure returns (bytes32) {
        return keccak256(abi.encode(i));
    }
}
