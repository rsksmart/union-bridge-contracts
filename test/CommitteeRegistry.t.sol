// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {Role, Member, CommitteeMember, Committee, CommitteeRegistry} from "src/CommitteeRegistry.sol";
import {ICommitteeRegistry} from "src/interfaces/ICommitteeRegistry.sol";
import {StreamDenomination} from "src/interfaces/IStreamManager.sol";
import {HelperContract} from "test/helpers/HelperContract.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract TestCommitteeRegistry is Test, HelperContract {
    function setUp() external {
        runTestDeployScript();
    }

    function test_getCommittee_Success() external view {
        // Act
        Committee memory aCommittee = registry.getCommittee(committee1Key);
        // Assert
        assertEqCommittee(aCommittee, committee1, "getted committee1");
    }

    function test_getCommitteeMemberIndices_Success() external view {
        // Act
        CommitteeMember[] memory members = registry.getCommitteeMember(committee1Key);
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
        // Arrange
        uint256 previousLength = registry.getCommitteesLength();
        // Act
        // registry.registerMember(generatePubKey(2), requestedStreams, requestedRoles);
        registry.registerMember(generatePubKey(3), requestedStreams, requestedRoles);
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
        CommitteeMember[] memory members = registry.getCommitteeMember(committee2Key);
        assertEqCommitteeMembers(members, committee2Members, "registered committee1");
    }

    function test_registerCommittee_Revert_AlreadyRegistered() external {
        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(ICommitteeRegistry.AlreadyRegisteredCommittee.selector, committee1.internalKey)
        );
        // Act
        registry.registerCommittee(committee1);
    }

    function test_registerCommittee_Revert_TooManyMembersPerCommittee() external {
        // Arrange
        Committee memory aCommittee;
        uint256 MAX_MEMBERS_PER_COMMITTEE = registry.MAX_MEMBERS_PER_COMMITTEE();
        CommitteeMember[] memory committee2Members = new CommitteeMember[](MAX_MEMBERS_PER_COMMITTEE + 1);
        // We start at 3 as we already have 3 members registered in the setup
        for (uint8 i = 3; i < committee2Members.length; i++) {
            vm.startBroadcast(uint256(i));
            registry.registerMember(bytes32(uint256(i)), requestedStreams, requestedRoles);
            vm.stopBroadcast();
            committee2Members[i] = CommitteeMember({index: i, role: Role.Operator});
        }
        aCommittee = Committee({internalKey: committee2Key, memberIndexesAndRoles: committee2Members, leaderIndex: 0});

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(ICommitteeRegistry.TooManyMembersPerCommittee.selector, MAX_MEMBERS_PER_COMMITTEE)
        );
        // Act
        registry.registerCommittee(aCommittee);
    }

    function test_registerCommittee_Revert_TooManyCommittees() external {
        // Arrange
        uint256 MAX_COMMITTEES_SIZE = registry.MAX_COMMITTEES_SIZE();
        bytes32 aCommitteeKey;
        Committee memory aCommittee;
        CommitteeMember[] memory aCommitteeMembers;

        // We start at 1 as we already have a committee registered at set
        for (uint256 i = 1; i < MAX_COMMITTEES_SIZE; i++) {
            aCommitteeMembers = new CommitteeMember[](2);
            aCommitteeMembers[0] = CommitteeMember({index: 0, role: Role.Operator});
            aCommitteeMembers[1] = CommitteeMember({index: 1, role: Role.Operator});
            aCommitteeKey = uintToBytes32(i);
            aCommittee =
                Committee({internalKey: aCommitteeKey, memberIndexesAndRoles: aCommitteeMembers, leaderIndex: 0});

            registry.registerCommittee(aCommittee);
        }

        aCommitteeMembers = new CommitteeMember[](2);
        aCommitteeMembers[0] = CommitteeMember({index: 0, role: Role.Operator});
        aCommitteeMembers[1] = CommitteeMember({index: 1, role: Role.Operator});
        aCommitteeKey = uintToBytes32(MAX_COMMITTEES_SIZE);
        aCommittee = Committee({internalKey: aCommitteeKey, memberIndexesAndRoles: aCommitteeMembers, leaderIndex: 0});

        // Assert
        vm.expectRevert(abi.encodeWithSelector(ICommitteeRegistry.TooManyCommittees.selector, MAX_COMMITTEES_SIZE));
        // Act
        registry.registerCommittee(aCommittee);
    }

    function test_registerMember_Revert_AlreadyRegistered() external {
        // Arrange
        vm.startBroadcast(uint256(generatePubKey(10)));
        registry.registerMember(generatePubKey(10), requestedStreams, requestedRoles);
        vm.stopBroadcast();

        // Assert
        vm.expectRevert(abi.encodeWithSelector(ICommitteeRegistry.AlreadyRegisteredMember.selector, generatePubKey(10)));

        // Act
        vm.startBroadcast(uint256(generatePubKey(10)));
        registry.registerMember(generatePubKey(10), requestedStreams, requestedRoles);
        vm.stopBroadcast();
    }

    function test_registerCommittee_Revert_nonRegisteredMember() external {
        // Assert
        vm.expectRevert(abi.encodeWithSelector(ICommitteeRegistry.NonRegisteredMember.selector, 62));
        // Act
        registry.registerCommittee(invalidCommittee);
    }

    function test_registerMember_Revert_TooManyMembers() external {
        // Arrange
        uint256 MAX_MEMBERS_SIZE = registry.MAX_MEMBERS_SIZE();
        // we already have 48 members registered in the setup
        for (uint16 i = 48; i < MAX_MEMBERS_SIZE; i++) {
            vm.startBroadcast(uint256(i));
            registry.registerMember(bytes32(uint256(i)), requestedStreams, requestedRoles);
            vm.stopBroadcast();
        }

        // Assert
        vm.expectRevert(abi.encodeWithSelector(ICommitteeRegistry.TooManyMembers.selector, MAX_MEMBERS_SIZE));
        // Act
        registry.registerMember(generatePubKey(MAX_MEMBERS_SIZE), requestedStreams, requestedRoles);
    }

    function test_registerMember_Revert_RequestedDifferentStreamsAndRolesLength() external {
        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(ICommitteeRegistry.RequestedDifferentStreamsAndRolesLength.selector, 1, 2)
        );
        // Act
        registry.registerMember(generatePubKey(10), new StreamDenomination[](1), new Role[](2));
    }

    function test_registerMember_Revert_RequestedNoRoles() external {
        // Assert
        vm.expectRevert(abi.encodeWithSelector(ICommitteeRegistry.RequestedNoRoles.selector));
        // Act
        registry.registerMember(generatePubKey(10), new StreamDenomination[](0), new Role[](0));
    }

    function test_registerMember_Revert_RequestedNoneRoleForStream() external {
        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(ICommitteeRegistry.RequestedNoneRoleForStream.selector, StreamDenomination._0_001BTC)
        );
        // Act
        // Role.None is default for Role
        registry.registerMember(generatePubKey(10), new StreamDenomination[](1), new Role[](1));
    }

    function test_registerMember_Revert_RequestedMultipleRolesForStream() external {
        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                ICommitteeRegistry.RequestedMultipleRolesForStream.selector,
                StreamDenomination._0_001BTC,
                Role.Operator,
                Role.Watchtower
            )
        );
        // Act
        Role[] memory roles = new Role[](2);
        roles[0] = Role.Operator;
        roles[1] = Role.Watchtower;
        // StreamDenomination._0_001BTC is default for StreamDenomination
        registry.registerMember(generatePubKey(10), new StreamDenomination[](2), roles);
    }

    function test_selectCommittee_Success() external {
        // Act
        CommitteeMember[] memory selectedMembers = registry.selectCommittee(0);

        // Assert - Verify committee has correct size
        assertEq(selectedMembers.length, 10, "Committee should have 10 members");

        // Count roles in selection
        uint256 watchtowerCount = 0;
        uint256 operatorCount = 0;
        for (uint256 i = 0; i < selectedMembers.length; i++) {
            if (selectedMembers[i].role == Role.Watchtower) watchtowerCount++;
            else if (selectedMembers[i].role == Role.Operator) operatorCount++;
        }

        // Verify correct role distribution
        assertEq(watchtowerCount, 3, "Committee should have 3 watchtowers");
        assertEq(operatorCount, 7, "Committee should have 7 operators");
    }

    function test_selectCommittee_ReturnsDifferentCommittees() external {
        // First selection with timestamp 1
        vm.warp(1);
        CommitteeMember[] memory selectedMembers1 = registry.selectCommittee(0);

        // Second selection with different timestamp
        vm.warp(1000);
        CommitteeMember[] memory selectedMembers2 = registry.selectCommittee(0);

        // Verify both selections have correct size
        assertEq(selectedMembers1.length, 10, "First committee should have 10 members");
        assertEq(selectedMembers2.length, 10, "Second committee should have 10 members");

        // Verify selections are different (at least one member is in a different position)
        bool isDifferent = false;
        for (uint256 i = 0; i < selectedMembers1.length; i++) {
            if (selectedMembers1[i].index != selectedMembers2[i].index) {
                isDifferent = true;
                break;
            }
        }
        assertTrue(isDifferent, "Selections should be different with different timestamps");
    }

    function test_selectCommittee_Revert_NotEnoughWatchtowers() external {
        // Assert that selectCommittee reverts with NotEnoughWatchtowers error
        vm.expectRevert(abi.encodeWithSelector(ICommitteeRegistry.NotEnoughWatchtowers.selector, 3, 2));

        // Act - try to select committee for the test denomination (streamId 1 = _0_01BTC)
        registry.selectCommittee(1);
    }

    function test_selectCommittee_Revert_NotEnoughOperators() external {
        // Assert that selectCommittee reverts with NotEnoughOperators error
        vm.expectRevert(abi.encodeWithSelector(ICommitteeRegistry.NotEnoughOperators.selector, 3, 2));

        // Act - try to select committee for the test denomination (streamId 2 = _0_1BTC)
        registry.selectCommittee(2);
    }

    function test_registerMember_Revert_NotEnoughMembers() external {
        // Assert
        vm.expectRevert(abi.encodeWithSelector(ICommitteeRegistry.NotEnoughMembers.selector, 10, 6));
        // Act
        registry.selectCommittee(3);
    }
}
