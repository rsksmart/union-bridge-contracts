// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {Role, Member, Committee, CommitteeRegistry} from "src/CommitteeRegistry.sol";
import {HelperContract} from "test/helpers/HelperContract.sol";

contract TestCommitteeRegistry is Test, HelperContract {
    function setUp() external {
        setUpCommittees();

        registry = new CommitteeRegistry();
        registry.initialize();

        // Register members with their mock keys
        registry.registerMember(COMMITTEE_1_MEMBER_1_PUB_KEY, Role.Operator);
        registry.registerMember(COMMITTEE_1_MEMBER_2_PUB_KEY, Role.Operator);

        registry.registerCommittee(committee1);
    }

    function test_getCommittee_Success() external view {
        // Act
        Committee memory aCommittee = registry.getCommittee(committee1Key);
        // Assert
        assertEqCommittee(aCommittee, committee1, "getted committee1");
    }

    function test_getCommitteeMemberIndices_Success() external view {
        // Act
        uint8[] memory members = registry.getCommitteeMemberIndices(committee1Key);
        // Assert
        assertEqCommitteeMembers(members, committee1Members, "getted committee1 members");
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
        // Assert
        assertEq(aCommitteeKey, committee1Key, "expected obtained key by index to be the same as the setup committee1");
    }

    function test_registerCommittee_Success() external {
        // Arrenge
        uint256 previousLength = registry.getCommitteesLength();
        // Act
        registry.registerMember(COMMITTEE_2_MEMBER_1_PUB_KEY, Role.Operator);
        registry.registerMember(COMMITTEE_2_MEMBER_2_PUB_KEY, Role.Operator);
        registry.registerCommittee(committee2);
        // Assert
        // Committee
        uint256 actualLength = registry.getCommitteesLength();
        assertEq(actualLength, previousLength + 1, "expected committees length should be previous + 1");
        Committee memory aCommittee = registry.getCommittee(committee2Key);
        assertEqCommittee(aCommittee, committee2, "registered committee1");
        bytes32 actualKey = registry.getCommitteeByIndex(previousLength);
        assertEq(actualKey, committee2Key, "expected obtained key by index to be the same as the registered committee1");

        // Members
        uint8[] memory members = registry.getCommitteeMemberIndices(committee2Key);
        assertEqCommitteeMembers(members, committee2Members, "registered committee1");
    }

    function test_registerCommittee_Revert_AlreadyRegistered() external {
        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(CommitteeRegistry.alreadyRegisteredCommittee.selector, committee1.internalKey)
        );
        // Act
        registry.registerCommittee(committee1);
    }

    function test_registerCommittee_Revert_TooManyMembersPerComitee() external {
        // Arrenge
        uint256 MAX_MEMBERS_PER_COMMITTEE = registry.MAX_MEMBERS_PER_COMMITTEE();
        uint8[] memory committee2Members = new uint8[](MAX_MEMBERS_PER_COMMITTEE + 1);
        for (uint8 i = 0; i < committee2Members.length; i++) {
            registry.registerMember(bytes32(uint256(i)), Role.Operator);
            committee2Members[i] = i;
        }
        committee2 = Committee({internalKey: committee2Key, memberIndices: committee2Members, leaderIndex: 0});

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(CommitteeRegistry.tooManyMembersPerComitee.selector, MAX_MEMBERS_PER_COMMITTEE)
        );
        // Act
        registry.registerCommittee(committee2);
    }

    function test_registerCommittee_Revert_TooManyCommittees() external {
        // Arrenge
        uint256 MAX_COMMITTEES_SIZE = registry.MAX_COMMITTEES_SIZE();
        bytes32 aCommitteeKey;
        Committee memory aCommittee;
        uint8[] memory aCommitteeMembers;

        // We start at 1 as we already have a committee registered at set
        for (uint256 i = 1; i < MAX_COMMITTEES_SIZE; i++) {
            aCommitteeMembers = new uint8[](2);
            aCommitteeMembers[0] = 0;
            aCommitteeMembers[1] = 1;
            aCommitteeKey = uintToBytes32(i);
            aCommittee = Committee({internalKey: aCommitteeKey, memberIndices: aCommitteeMembers, leaderIndex: 0});

            registry.registerCommittee(aCommittee);
        }

        aCommitteeMembers = new uint8[](2);
        aCommitteeMembers[0] = 3;
        aCommitteeMembers[1] = 4;
        aCommitteeKey = uintToBytes32(MAX_COMMITTEES_SIZE);
        aCommittee = Committee({internalKey: aCommitteeKey, memberIndices: aCommitteeMembers, leaderIndex: 0});

        // Assert
        vm.expectRevert(abi.encodeWithSelector(CommitteeRegistry.tooManyCommittees.selector, MAX_COMMITTEES_SIZE));
        // Act
        registry.registerCommittee(aCommittee);
    }

    function test_registerMember_Revert_AlreadyRegistered() external {
        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(CommitteeRegistry.alreadyRegisteredMember.selector, COMMITTEE_1_MEMBER_1_PUB_KEY)
        );
        // Act
        registry.registerMember(COMMITTEE_1_MEMBER_1_PUB_KEY, Role.Operator);
    }

    function test_registerCommittee_Revert_nonRegisteredMember() external {
        // Assert
        vm.expectRevert(abi.encodeWithSelector(CommitteeRegistry.nonRegisteredMember.selector, 2));
        // Act
        registry.registerCommittee(committee2);
    }

    function test_registerMember_Revert_TooManyMembers() external {
        // Arrenge
        uint256 MAX_MEMBERS_SIZE = registry.MAX_MEMBERS_SIZE();
        // -2 because we already have 2 members registered in the setup
        for (uint16 i = 0; i < MAX_MEMBERS_SIZE - 2; i++) {
            registry.registerMember(bytes32(uint256(i)), Role.Operator);
        }

        // Assert
        vm.expectRevert(abi.encodeWithSelector(CommitteeRegistry.tooManyMembers.selector, MAX_MEMBERS_SIZE));
        // Act
        registry.registerMember(bytes32(uint256(MAX_MEMBERS_SIZE)), Role.Operator);
    }
}
