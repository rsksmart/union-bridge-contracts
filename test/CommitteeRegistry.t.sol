// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {Role, Member, CommitteeMember, Committee, CommitteeRegistry} from "src/CommitteeRegistry.sol";
import {StreamDenomination} from "src/interfaces/IStreamManager.sol";
import {ICommitteeRegistry} from "src/interfaces/ICommitteeRegistry.sol";
import {HelperContract} from "test/helpers/HelperContract.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract TestCommitteeRegistry is Test, HelperContract {
    function setUp() external {
        CommitteeRegistry registryImpl = new CommitteeRegistry();
        address upgradableOwner = msg.sender;
        ERC1967Proxy proxy =
            new ERC1967Proxy(address(registryImpl), abi.encodeCall(CommitteeRegistry.initialize, (upgradableOwner)));
        registry = CommitteeRegistry(address(proxy));

        setUpCommittees();

        // Register members with their mock keys
        vm.prank(MEMBER_0_ADDRESS);
        registry.registerMember(MEMBER_0_PUBKEY, requestedStreams, requestedRoles);

        vm.prank(MEMBER_1_ADDRESS);
        registry.registerMember(MEMBER_1_PUBKEY, requestedStreams, requestedRoles);

        registry.registerCommittee(committee1Id, committee1);
    }

    // function test_getCommittee_Success() external view {
    //     // Act
    //     Committee memory aCommittee = registry.getCommittee(committee1Key);
    //     // Assert
    //     assertEqCommittee(aCommittee, committee1, "getted committee1");
    // }

    // function test_getCommitteeMemberIndices_Success() external view {
    //     // Act
    //     CommitteeMember[] memory members = registry.getCommitteeMembers(committee1Key);
    //     // Assert
    //     assertEqCommitteeMembers(members, committee1Members, "getted committee1 members");
    // }

    // function test_getCommitteeByIndex_Success() external view {
    //     // Act
    //     bytes32 aCommitteeKey = registry.getCommitteeByIndex(0);
    //     // Assert
    //     assertEq(aCommitteeKey, committee1Key, "expected obtained key by index to be the same as the setup committee1");
    // }

    function test_registerCommittee_Success() external {
        // Arrange
        // uint256 previousLength = registry.getCommitteesLength();
        // Act
        vm.prank(MEMBER_2_ADDRESS);
        registry.registerMember(generatePubKey(2), requestedStreams, requestedRoles);
        registry.registerCommittee(committee2Id, committee2);
        // Assert
        // Committee
        // uint256 actualLength = registry.getCommitteesLength();
        // assertEq(actualLength, previousLength + 1, "expected committees length should be previous + 1");
        Committee memory aCommittee = registry.getCommittee(committee2Id);
        assertEqCommittee(aCommittee, committee2, "registered committee1");
        // bytes32 actualKey = registry.getCommitteeByIndex(previousLength);
        // assertEq(actualKey, committee2Key, "expected obtained key by index to be the same as the registered committee1");

        // Members
        // CommitteeMember[] memory members = registry.getCommitteeMembers(committee2Key);
        // assertEqCommitteeMembers(members, committee2Members, "registered committee1");
    }

    // function test_registerCommittee_Revert_AlreadyRegistered() external {
    //     // Assert
    //     vm.expectRevert(
    //         abi.encodeWithSelector(ICommitteeRegistry.AlreadyRegisteredCommittee.selector, committee1.aggregatedKey)
    //     );
    //     // Act
    //     registry.registerCommittee(committee1);
    // }

    // function test_registerCommittee_Revert_TooManyMembersPerComitee() external {
    //     // Arrange
    //     Committee memory aCommittee;
    //     uint256 MAX_MEMBERS_PER_COMMITTEE = registry.MAX_MEMBERS_PER_COMMITTEE();
    //     CommitteeMember[] memory committee2Members = new CommitteeMember[](MAX_MEMBERS_PER_COMMITTEE + 1);
    //     // We start at 2 as we already have 2 members registered in the setup
    //     for (uint8 i = 2; i < committee2Members.length; i++) {
    //         registry.registerMember(bytes32(uint256(i)), requestedStreams, requestedRoles);
    //         committee2Members[i] = CommitteeMember({index: i, role: Role.Operator});
    //     }
    //     aCommittee = Committee({aggregatedKey: committee2Key, memberIndexesAndRoles: committee2Members, leaderIndex: 0});

    //     // Assert
    //     vm.expectRevert(
    //         abi.encodeWithSelector(ICommitteeRegistry.TooManyMembersPerComitee.selector, MAX_MEMBERS_PER_COMMITTEE)
    //     );
    //     // Act
    //     registry.registerCommittee(aCommittee);
    // }

    // function test_registerCommittee_Revert_TooManyCommittees() external {
    //     // Arrange
    //     uint256 MAX_COMMITTEES_SIZE = registry.MAX_COMMITTEES_SIZE();
    //     bytes32 aCommitteeKey;
    //     Committee memory aCommittee;
    //     CommitteeMember[] memory aCommitteeMembers;

    //     // We start at 1 as we already have a committee registered at set
    //     for (uint256 i = 1; i < MAX_COMMITTEES_SIZE; i++) {
    //         aCommitteeMembers = new CommitteeMember[](2);
    //         aCommitteeMembers[0] = CommitteeMember({index: 0, role: Role.Operator});
    //         aCommitteeMembers[1] = CommitteeMember({index: 1, role: Role.Operator});
    //         aCommitteeKey = uintToBytes32(i);
    //         aCommittee =
    //             Committee({aggregatedKey: aCommitteeKey, memberIndexesAndRoles: aCommitteeMembers, leaderIndex: 0});

    //         registry.registerCommittee(aCommittee);
    //     }

    //     aCommitteeMembers = new CommitteeMember[](2);
    //     aCommitteeMembers[0] = CommitteeMember({index: 0, role: Role.Operator});
    //     aCommitteeMembers[1] = CommitteeMember({index: 1, role: Role.Operator});
    //     aCommitteeKey = uintToBytes32(MAX_COMMITTEES_SIZE);
    //     aCommittee = Committee({aggregatedKey: aCommitteeKey, memberIndexesAndRoles: aCommitteeMembers, leaderIndex: 0});

    //     // Assert
    //     vm.expectRevert(abi.encodeWithSelector(ICommitteeRegistry.TooManyCommittees.selector, MAX_COMMITTEES_SIZE));
    //     // Act
    //     registry.registerCommittee(aCommittee);
    // }

    // function test_registerMember_Revert_AlreadyRegistered() external {
    //     // Arrange
    //     registry.registerMember(generatePubKey(1), requestedStreams, requestedRoles);

    //     // Assert
    //     vm.expectRevert(abi.encodeWithSelector(ICommitteeRegistry.AlreadyRegisteredMember.selector, generatePubKey(1)));
    //     // Act
    //     registry.registerMember(generatePubKey(1), requestedStreams, requestedRoles);
    // }

    // function test_registerCommittee_Revert_NonRegisteredMember() external {
    //     // Assert
    //     vm.expectRevert(abi.encodeWithSelector(ICommitteeRegistry.NonRegisteredMember.selector, 2));
    //     // Act
    //     registry.registerCommittee(committee2);
    // }

    function test_registerMember_Revert_TooManyMembers() external {
        // Arrange
        uint256 MAX_MEMBERS_SIZE = registry.MAX_MEMBERS_SIZE();
        bytes32 memberAddress = keccak256(abi.encodePacked(MEMBER_0_ADDRESS));
        // -2 because we already have 2 members registered in the setup
        for (uint16 i = 2; i < MAX_MEMBERS_SIZE; i++) {
            memberAddress = keccak256(abi.encodePacked(memberAddress));
            vm.prank(address(uint160(uint256(memberAddress))));
            registry.registerMember(bytes32(uint256(i)), requestedStreams, requestedRoles);
        }

        // Assert
        vm.expectRevert(abi.encodeWithSelector(ICommitteeRegistry.TooManyMembers.selector, MAX_MEMBERS_SIZE));
        // Act
        memberAddress = keccak256(abi.encodePacked(memberAddress));
        vm.prank(address(uint160(uint256(memberAddress))));
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
}
