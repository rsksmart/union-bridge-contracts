// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {Committee, CommitteeRegistry} from "src/CommitteeRegistry.sol";
import {HelperContract} from "test/helpers/HelperContract.sol";

contract TestCommitteeRegistry is Test, HelperContract {
    function setUp() external {
        setUpCommittees();

        registry = new CommitteeRegistry();
        registry.initialize();

        registry.registerCommittee(committee1, memebersCommittee1);
    }

    function test_getCommittee_Success() external view {
        // Act
        Committee memory aCommittee = registry.getCommittee(committee1Key);
        // Assert
        assertEqCommittee(aCommittee, committee1, "getted committee1");
    }

    function test_getCommitteeMembers_Success() external view {
        // Act
        address[] memory members = registry.getCommitteeMembers(committee1Key);
        // Assert
        assertEqCommitteeMembers(members, memebersCommittee1, "getted committee1 memebers");
    }

    function test_getCommitteesLength_Success() external view {
        // Act
        uint256 length = registry.getCommitteesLength();
        // Assert
        assertEq(length, 1, "expected committees length should be 1");
    }

    function test_getCommitteeByIndex_Success() external view {
        // Act
        bytes32 aCommitteeKey = registry.getCommitteeByIndex(0);
        (committee1Key);
        // Assert
        assertEq(aCommitteeKey, committee1Key, "expected obtained key by index to be the same as the setup committee1");
    }

    function test_registerCommittee_Success() external {
        // Arrenge
        uint256 previousLength = registry.getCommitteesLength();
        // Act
        registry.registerCommittee(committee2, memebersCommittee2);
        // Assert
        // Committee
        uint256 actualLength = registry.getCommitteesLength();
        assertEq(actualLength, previousLength + 1, "expected committees length should be previous + 1");
        Committee memory aCommittee = registry.getCommittee(committee2Key);
        assertEqCommittee(aCommittee, committee2, "registered committee1");
        bytes32 actualKey = registry.getCommitteeByIndex(previousLength);
        assertEq(actualKey, committee2Key, "expected obtained key by index to be the same as the registered committee1");

        // Members
        address[] memory members = registry.getCommitteeMembers(committee2Key);
        assertEqCommitteeMembers(members, memebersCommittee2, "registered committee1");
    }

    function test_registerCommittee_Revert_AlreadyRegistered() external {
        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(CommitteeRegistry.alreadyRegisteredCommittee.selector, committee1.internalKey)
        );
        // Act
        registry.registerCommittee(committee1, memebersCommittee1);
    }

    function test_registerCommittee_Revert_TooManyMemebers() external {
        // Arrenge
        uint256 MAX_MEMBERS_SIZE = registry.MAX_MEMBERS_SIZE();
        address[] memory memebersCommittee2 = new address[](MAX_MEMBERS_SIZE + 1);
        for (uint256 i = 0; i < memebersCommittee2.length; i++) {
            memebersCommittee2[i] = uintToAddress(i);
        }
        // Assert
        vm.expectRevert(abi.encodeWithSelector(CommitteeRegistry.tooManyMembers.selector, MAX_MEMBERS_SIZE));
        // Act
        registry.registerCommittee(committee2, memebersCommittee2);
    }

    function test_registerCommittee_Revert_TooManyCommittees() external {
        // Arrenge
        uint256 MAX_COMITTEE_SIZE = registry.MAX_COMITTEE_SIZE();
        bytes32 aCommitteeKey;
        Committee memory aCommittee;
        address[] memory aMemebersCommittee;

        // We start at 1 as we already have a committee registered at set
        for (uint256 i = 1; i < MAX_COMITTEE_SIZE; i++) {
            aCommitteeKey = uintToBytes32(i);
            aCommittee = Committee({internalKey: aCommitteeKey, leader: vm.addr(3), backupLeader: vm.addr(4)});
            aMemebersCommittee = new address[](2);
            aMemebersCommittee[0] = vm.addr(3);
            aMemebersCommittee[1] = vm.addr(4);

            registry.registerCommittee(aCommittee, aMemebersCommittee);
        }

        aCommitteeKey = uintToBytes32(MAX_COMITTEE_SIZE);
        aCommittee = Committee({internalKey: aCommitteeKey, leader: vm.addr(3), backupLeader: vm.addr(4)});
        aMemebersCommittee = new address[](2);
        aMemebersCommittee[0] = vm.addr(3);
        aMemebersCommittee[1] = vm.addr(4);

        // Assert
        vm.expectRevert(abi.encodeWithSelector(CommitteeRegistry.tooManyCommittees.selector, MAX_COMITTEE_SIZE));
        // Act
        registry.registerCommittee(aCommittee, aMemebersCommittee);
    }
}
