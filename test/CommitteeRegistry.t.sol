// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {Role, Member, CommitteeMember, Committee, CommitteeRegistry} from "src/CommitteeRegistry.sol";
import {StreamDenomination} from "src/interfaces/IStreamManager.sol";
import {ICommitteeRegistry} from "src/interfaces/ICommitteeRegistry.sol";
import {HelperContract} from "test/helpers/HelperContract.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IStreamManager} from "src/interfaces/IStreamManager.sol";

contract TestCommitteeRegistry is Test, HelperContract {
    function setUp() external {
        runTestDeployScript();
    }

    function test_getCommittee_Success() external view {
        // Act
        Committee memory aCommittee = registry.getCommittee(COMMITTEE_1_ID);
        // Assert
        assertEqCommittee(aCommittee, committee1, "getted committee1");
    }

    function test_getCommitteeMembers_Success() external view {
        // Act
        CommitteeMember[] memory members = registry.getCommitteeMembers(COMMITTEE_1_ID);
        // Assert
        assertEqCommitteeMembers(members, committee1Members, "getted committee1 members");
    }

    function test_registerCommittee_Success() external {
        // Assert
        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.NewCommittee(COMMITTEE_2_ID, committee2);

        // Act
        registry.registerCommittee(COMMITTEE_2_ID, committee2);

        // Assert
        // Committee
        Committee memory aCommittee = registry.getCommittee(COMMITTEE_2_ID);
        assertEqCommittee(aCommittee, committee2, "registered committee2");

        // Members
        CommitteeMember[] memory members = registry.getCommitteeMembers(COMMITTEE_2_ID);
        assertEqCommitteeMembers(members, committee2Members, "registered committee2");
    }

    function test_registerCommittee_Revert_AlreadyRegistered() external {
        // Assert
        vm.expectRevert(abi.encodeWithSelector(ICommitteeRegistry.AlreadyRegisteredCommittee.selector, COMMITTEE_1_ID));
        // Act
        registry.registerCommittee(COMMITTEE_1_ID, committee1);
    }

    function test_registerMember_Revert_AlreadyRegistered() external {
        // Arrange
        vm.prank(MEMBER_3_ADDRESS);
        registry.registerMember(MEMBER_3_PUBKEY, requestedStreams, requestedRoles);

        // Assert
        vm.expectRevert(abi.encodeWithSelector(ICommitteeRegistry.AlreadyRegisteredMember.selector, MEMBER_3_ADDRESS));

        // Act
        vm.prank(MEMBER_3_ADDRESS);
        registry.registerMember(MEMBER_3_PUBKEY, requestedStreams, requestedRoles);
    }

    function test_registerMember_Revert_TooManyMembers() external {
        // Arrange
        uint256 MAX_MEMBERS_SIZE = registry.MAX_MEMBERS_SIZE();
        // -2 because we already have 2 members registered in the setup
        for (uint16 i = 3; i < MAX_MEMBERS_SIZE; i++) {
            vm.prank(vm.addr(i));
            registry.registerMember(bytes32(uint256(i)), requestedStreams, requestedRoles);
        }

        // Assert
        vm.expectRevert(abi.encodeWithSelector(ICommitteeRegistry.TooManyMembers.selector, MAX_MEMBERS_SIZE));
        // Act
        vm.prank(vm.addr(MAX_MEMBERS_SIZE));
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

    function test_getMemberPubKeyByIndex_Revert_MemberIndexNotFound() external {
        // Assert
        vm.expectRevert(abi.encodeWithSelector(ICommitteeRegistry.MemberIndexNotFound.selector, 3));
        // Act
        registry.getMemberPubKeyByIndex(3);
    }

    function test_getMemberPubKeyByIndex_Success() external view {
        // Act
        bytes32 pubKey = registry.getMemberPubKeyByIndex(1);

        // Assert
        assertEq(pubKey, MEMBER_1_PUBKEY, "getted member1 pubkey by index 1");
    }

    function test_getMemberIndexByAddress_Success() external view {
        // Act
        uint16 memberIndex = registry.getMemberIndexByAddress(MEMBER_1_ADDRESS);

        // Assert
        assertEq(memberIndex, 1, "getted member1 index by address");
    }

    function test_getMemberIndexByAddress_Revert_MemberNotRegistered() external {
        // Assert
        vm.expectRevert(abi.encodeWithSelector(ICommitteeRegistry.MemberNotRegistered.selector, MEMBER_3_ADDRESS));

        // Act
        registry.getMemberIndexByAddress(MEMBER_3_ADDRESS);
    }

    function test_getPendingCommittee_Revert_CommitteeIsNotPending() external {
        // Assert
        vm.expectRevert(abi.encodeWithSelector(ICommitteeRegistry.CommitteeIsNotPending.selector, STREAM_ID));
        // Act
        registry.getPendingCommittee(STREAM_ID);
    }

    function test_createCommittee_Success() external {
        // Arrange
        Committee memory pendingCommittee = committee1;
        pendingCommittee.aggregatedKey = bytes32(0);

        // Assert
        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.NewPendingCommittee(STREAM_ID, pendingCommittee);

        // Act
        // This should create a committee as pending
        vm.prank(address(pm));
        registry.createCommittee(STREAM_ID);
    }

    function test_getPendingCommittee_Success() external {
        // Arrange
        setup_createCommittee(STREAM_ID);
        Committee memory expectedPendingCommittee = committee1;
        expectedPendingCommittee.aggregatedKey = bytes32(0);

        // Act
        (Committee memory committee, uint256 expiredAt, uint256 missingData) = registry.getPendingCommittee(STREAM_ID);

        // Assert
        assertEqCommittee(committee, expectedPendingCommittee, "get pending committee");
        assertNotEq(expiredAt, 0);
        assertEq(missingData, 2);
    }

    function test_depositMemberInfoForCommittee_Success() external {
        // Arrange
        setup_createCommittee(STREAM_ID);

        // Act
        vm.prank(MEMBER_0_ADDRESS);
        registry.depositMemberInfoForCommittee(STREAM_ID, COMMITEE_1_PUB_KEY);

        // Assert
        (Committee memory committee, uint256 expiredAt, uint256 missingData) = registry.getPendingCommittee(STREAM_ID);
        assertEqCommittee(committee, committee1, "get pending committee");
        assertNotEq(expiredAt, 0);
        assertEq(missingData, 1);
    }

    function test_depositMemberInfoForCommittee_WrongCommitteeKey() external {
        // Arrange
        setup_createCommittee(STREAM_ID);
        setup_depositMemberInfo(STREAM_ID, MEMBER_0_ADDRESS);
        Committee memory expectedPendingCommittee = committee1;
        expectedPendingCommittee.aggregatedKey = bytes32(0);

        // Assert
        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.NewPendingCommittee(STREAM_ID, expectedPendingCommittee);

        // Act
        // Second member deposit wrong committee aggregated key, so discard current pending committee a create a new one.
        vm.prank(MEMBER_1_ADDRESS);
        registry.depositMemberInfoForCommittee(STREAM_ID, COMMITEE_2_PUB_KEY);

        // Assert
        (Committee memory committee, uint256 expiredAt, uint256 missingData) = registry.getPendingCommittee(STREAM_ID);
        assertEqCommittee(committee, expectedPendingCommittee, "get pending committee");
        assertNotEq(expiredAt, 0);
        assertEq(missingData, 2);
    }

    function test_depositMemberInfoForCommittee_CompleteCommittee_Success() external {
        // Arrange
        setup_createCommittee(STREAM_ID);
        setup_depositMemberInfo(STREAM_ID, MEMBER_0_ADDRESS);

        // Assert
        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.NewCommittee(
            75506153327051474587906755573858019282972751592871715030499431892688993766217, committee1
        );

        // Act
        vm.prank(MEMBER_1_ADDRESS);
        registry.depositMemberInfoForCommittee(STREAM_ID, COMMITEE_1_PUB_KEY);
    }

    function test_getPendingCommittee_Revert_CommitteeIsNotPending_AfterCompleteCommittee() external {
        // Arrange
        setup_createCommittee(STREAM_ID);
        setup_depositMemberInfo(STREAM_ID, MEMBER_0_ADDRESS);
        setup_depositMemberInfo(STREAM_ID, MEMBER_1_ADDRESS);

        // Assert
        vm.expectRevert(abi.encodeWithSelector(ICommitteeRegistry.CommitteeIsNotPending.selector, STREAM_ID));
        // Act
        registry.getPendingCommittee(STREAM_ID);
    }

    function test_isPendingCommitteeExpired_False_BeforeCreateCommittee() external view {
        // Act
        bool isCommitteePendingExpired = registry.isPendingCommitteeExpired(STREAM_ID);
        // Assert
        // There is no pending committee so it's not expired
        assertFalse(isCommitteePendingExpired, "pending committee is expired");
    }

    function test_isPendingCommitteeExpired_False_AfterCreateCommittee() external {
        // Arrange
        setup_createCommittee(STREAM_ID);

        // Act
        bool isCommitteePendingExpired = registry.isPendingCommitteeExpired(STREAM_ID);
        // Assert
        // There is pending committee and it's not expired
        assertFalse(isCommitteePendingExpired, "pending committee is expired");
    }

    function test_isPendingCommitteeExpired_True() external {
        // Arrange
        setup_createCommittee(STREAM_ID);
        uint256 timelock = registry.pendingCommitteeTimelock();
        vm.warp(block.timestamp + timelock + 1 seconds); // warp time to make committee expired

        // Act
        bool isCommitteePendingExpired = registry.isPendingCommitteeExpired(STREAM_ID);
        // Assert
        // There is pending committee and it's expired
        assertTrue(isCommitteePendingExpired, "pending committee is not expired");
    }

    function test_createCommittee_UnauthorizedAccount() external {
        // Assert
        vm.expectRevert(abi.encodeWithSelector(ICommitteeRegistry.UnauthorizedAccount.selector, address(this)));

        // Act
        registry.createCommittee(STREAM_ID);
    }
}
