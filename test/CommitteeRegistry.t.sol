// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {Committee, CommitteeRegistry} from "src/CommitteeRegistry.sol";
import {HelperContract} from "test/HelperContract.sol";

// TODO
contract TestCommitteeRegistry is Test, HelperContract {
    Committee committee;
    bytes32 committeeKey;
    address[] memebersCommittee;

    function setUp() external {
        registry = new CommitteeRegistry();
        registry.initialize();

        committeeKey = hex"0908421cb37d204b0c68660d093534d50d01fa791a3313e5fd9c21da137785eb";
        committee = Committee({internalKey: committeeKey, leader: address(this), backupLeader: vm.addr(1)});

        memebersCommittee = new address[](2);
        memebersCommittee[0] = address(this);
        memebersCommittee[1] = vm.addr(1);

        registry.registerCommittee(committee, memebersCommittee);
    }

    function test_getCommittee_Success() external {
        // Act
        Committee memory aCommittee = registry.getCommittee(committeeKey);
        // Assert
        assertEqCommittee(aCommittee, committee, "getted committee");
    }

    function test_getCommitteeMembers_Success() external {
        // Act
        address[] memory members = registry.getCommitteeMembers(committeeKey);
        // Assert
        assertEqCommitteeMembers(members, memebersCommittee, "getted committee memebers");
    }

    function test_registerCommittee_Success() external {
        // Arrenge
        bytes32 committeeKey2 = hex"1908421cb37d204b0c68660d093534d50d01fa791a3313e5fd9c21da137785ec";
        Committee memory committee2 =
            Committee({internalKey: committeeKey2, leader: vm.addr(3), backupLeader: vm.addr(4)});
        address[] memory memebersCommittee2 = new address[](2);
        memebersCommittee2[0] = vm.addr(3);
        memebersCommittee2[1] = vm.addr(4);
        // Act
        registry.registerCommittee(committee2, memebersCommittee2);
        // Assert
        // Committee
        Committee memory aCommittee = registry.getCommittee(committeeKey2);
        assertEqCommittee(aCommittee, committee2, "registered committee");
        // Members
        address[] memory members = registry.getCommitteeMembers(committeeKey2);
        assertEqCommitteeMembers(members, memebersCommittee2, "registered committee");
    }
}
