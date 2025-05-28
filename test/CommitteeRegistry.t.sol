// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {Role, Member, CommitteeMember, Committee, CommitteeRegistry} from "src/CommitteeRegistry.sol";
import {ICommitteeRegistry} from "src/interfaces/ICommitteeRegistry.sol";
import {SecurityBond} from "src/SecurityBond.sol";
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
        uint256 minimumDeposit = registry.getMinimumDepositById(defaultStream);
        registry.depositBond{value: minimumDeposit}(generatePubKey(3), defaultStream, defaultRole);
        // Act
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
        uint256 minimumDeposit = registry.getMinimumDepositById(defaultStream);
        Committee memory aCommittee;
        uint256 MAX_MEMBERS_PER_COMMITTEE = registry.MAX_MEMBERS_PER_COMMITTEE();
        CommitteeMember[] memory committee2Members = new CommitteeMember[](MAX_MEMBERS_PER_COMMITTEE + 1);
        // We start at 3 as we already have 3 members registered in the setup
        for (uint8 i = 3; i < committee2Members.length; i++) {
            uint256 privKey = uint256(i);
            // Add balance to the user
            address user = vm.addr(privKey);
            vm.deal(user, minimumDeposit);

            vm.startBroadcast(privKey);
            registry.depositBond{value: minimumDeposit}(bytes32(privKey), defaultStream, defaultRole);
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

    function test_depositBond_Revert_TooManyMembers() external {
        // Arrange
        uint256 MAX_MEMBERS_SIZE = registry.MAX_MEMBERS_SIZE();
        uint256 minimumDeposit = registry.getMinimumDepositById(defaultStream);
        // we already have 3 members registered in the setup
        for (uint16 i = 3; i < MAX_MEMBERS_SIZE; i++) {
            uint256 privKey = uint256(i);
            // Add balance to the user
            address user = vm.addr(privKey);
            vm.deal(user, minimumDeposit);

            vm.startBroadcast(privKey);
            registry.depositBond{value: minimumDeposit}(bytes32(privKey), defaultStream, defaultRole);
            vm.stopBroadcast();
        }

        // Assert
        vm.expectRevert(abi.encodeWithSelector(ICommitteeRegistry.TooManyMembers.selector, MAX_MEMBERS_SIZE));
        // Act
        registry.depositBond{value: minimumDeposit}(generatePubKey(MAX_MEMBERS_SIZE), defaultStream, defaultRole);
    }

    function test_depositBond_Success() external {
        // Arrange
        uint256 privKey = uint256(1);
        address user = vm.addr(privKey);
        uint256 minimumDeposit = registry.getMinimumDepositById(defaultStream);
        vm.deal(user, minimumDeposit);

        CommitteeMember[] memory committeesCandidates = registry.getCommitteeCandidates(defaultStream);
        uint256 candidatesAmountBefore = committeesCandidates.length;

        // Assert member registered
        vm.expectEmit(address(registry));
        emit CommitteeRegistry.newMember(bytes32(privKey));

        // Assert assert deposited bond
        vm.expectEmit(address(registry));
        emit SecurityBond.newSecurityBondDeposit(user, defaultStream, defaultRole, minimumDeposit);

        // Act
        vm.prank(user);
        registry.depositBond{value: minimumDeposit}(bytes32(privKey), defaultStream, defaultRole);

        // Assert
        // Member memory member = registry.getMemberByAddress(user);
        assertEq(
            registry.getMemberPublicKey(user), bytes32(privKey), "member public key should match the deposited key"
        );
        assertTrue(
            registry.getMemberRequestedRole(user, defaultStream) == defaultRole,
            "member requested role should match the requested role"
        );
        assertEq(registry.getMemberAvailableBalance(user), 0, "member available balance should be 0");
        assertEq(
            registry.getMemberPreStakedBalance(user, defaultStream),
            minimumDeposit,
            "member pre-staked should match the minimum deposit"
        );

        committeesCandidates = registry.getCommitteeCandidates(defaultStream);
        uint256 candidatesAmountAfter = committeesCandidates.length;
        assertEq(candidatesAmountBefore + 1, candidatesAmountAfter, "candidates amount should increase by 1");
        assertEq(
            (committeesCandidates[candidatesAmountAfter - 1].role == defaultRole),
            true,
            "candidate role should match requested role"
        );
    }

    function test_depositBond_Revert_memberAlreadyRegisteredForStream() external {
        // Arrange
        uint256 privKey = uint256(1);
        address user = vm.addr(privKey);
        uint256 minimumDeposit = registry.getMinimumDepositById(defaultStream);
        vm.deal(user, minimumDeposit);

        // Act
        vm.prank(user);
        registry.depositBond{value: minimumDeposit}(bytes32(privKey), defaultStream, Role.Operator);

        // Arrange
        vm.deal(user, minimumDeposit);

        // Assert member already registered for stream
        vm.expectRevert(
            abi.encodeWithSelector(
                ICommitteeRegistry.MemberAlreadyRegisteredForStream.selector,
                user,
                defaultStream,
                Role.Watchtower,
                Role.Operator
            )
        );

        // Act
        vm.prank(user);
        registry.depositBond{value: minimumDeposit}(bytes32(privKey), defaultStream, Role.Watchtower);
    }

    function test_depositBond_Revert_requestedNoneRoleForStream() external {
        // Arrange
        uint256 privKey = uint256(1);
        address user = vm.addr(privKey);
        uint256 minimumDeposit = registry.getMinimumDepositById(defaultStream);
        vm.deal(user, minimumDeposit);

        // Assert requested none role for stream
        vm.expectRevert(abi.encodeWithSelector(ICommitteeRegistry.RequestedNoneRoleForStream.selector, defaultStream));

        // Act
        vm.prank(user);
        registry.depositBond{value: minimumDeposit}(bytes32(privKey), defaultStream, Role.None);
    }

    function test_depositBond_Revert_despositBondTooLow() external {
        // Arrange
        uint256 privKey = uint256(1);
        address user = vm.addr(privKey);
        uint256 minimumDeposit = registry.getMinimumDepositById(defaultStream);
        vm.deal(user, minimumDeposit - 1);

        // Assert deposit bond too low
        vm.expectRevert(
            abi.encodeWithSelector(SecurityBond.despositBondTooLow.selector, minimumDeposit - 1, minimumDeposit)
        );

        // Act
        vm.prank(user);
        registry.depositBond{value: minimumDeposit - 1}(bytes32(privKey), defaultStream, defaultRole);
    }

    function test_unsuscribeFromStream_Success() external {
        // Arrange
        uint256 privKey = uint256(1);
        address user = vm.addr(privKey);
        uint256 minimumDeposit = registry.getMinimumDepositById(defaultStream);
        vm.deal(user, minimumDeposit);
        vm.prank(user);
        registry.depositBond{value: minimumDeposit}(bytes32(privKey), defaultStream, Role.Operator);
        CommitteeMember[] memory committeesCandidates = registry.getCommitteeCandidates(defaultStream);
        uint256 candidatesAmountBefore = committeesCandidates.length;

        // Assert
        vm.expectEmit(address(registry));
        emit CommitteeRegistry.memberUnsubscribedFromStream(user, defaultStream);
        vm.expectEmit(address(registry));
        emit SecurityBond.newAvailableBalance(user, minimumDeposit);

        // Act
        vm.prank(user);
        registry.unsuscribeFromStream(defaultStream);

        // Assert
        assertEq(
            registry.getMemberAvailableBalance(user),
            minimumDeposit,
            "member available balance should match the minimum deposit"
        );
        assertEq(
            registry.getMemberPreStakedBalance(user, defaultStream), 0, "member pre-staked should be 0 after unsuscribe"
        );
        assertTrue(
            registry.getMemberRequestedRole(user, defaultStream) == Role.None,
            "member requested role should be None after unsuscribe"
        );
        committeesCandidates = registry.getCommitteeCandidates(defaultStream);
        uint256 candidatesAmountAfter = committeesCandidates.length;
        assertEq(candidatesAmountBefore - 1, candidatesAmountAfter, "candidates amount should decrease by 1");
    }

    function test_unsuscribeFromStream_Revert_memberIsNotCandidateForStream() external {
        // Arrange
        uint256 privKey = uint256(1);
        address user = vm.addr(privKey);
        uint256 minimumDeposit = registry.getMinimumDepositById(StreamDenomination._0_001BTC);
        vm.deal(user, minimumDeposit);
        vm.prank(user);
        registry.depositBond{value: minimumDeposit}(bytes32(privKey), StreamDenomination._0_001BTC, Role.Operator);

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                ICommitteeRegistry.MemberIsNotCandidateForStream.selector, user, StreamDenomination._0_01BTC
            )
        );

        // Act
        vm.prank(user);
        registry.unsuscribeFromStream(StreamDenomination._0_01BTC);
    }

    function test_unsuscribeFromStream_Revert_nonRegisteredMember() external {
        // Arrange
        uint256 privKey = uint256(1);
        address user = vm.addr(privKey);

        // Assert
        vm.expectRevert(abi.encodeWithSelector(ICommitteeRegistry.NonRegisteredMember.selector, user));

        // Act
        vm.prank(user);
        registry.unsuscribeFromStream(defaultStream);
    }

    function test_withdrawAvailableBalance_Success() external {
        // Arrange
        uint256 privKey = uint256(1);
        address user = vm.addr(privKey);
        uint256 minimumDeposit = registry.getMinimumDepositById(defaultStream);
        vm.deal(user, minimumDeposit);

        vm.startBroadcast(user);
        registry.depositBond{value: minimumDeposit}(bytes32(privKey), defaultStream, defaultRole);
        registry.unsuscribeFromStream(defaultStream);
        vm.stopBroadcast();

        uint256 amount = registry.getMemberAvailableBalance(user);

        uint256 beforeWithdrawBalance = address(user).balance;

        // Assert
        vm.expectEmit(address(registry));
        emit SecurityBond.availableBalanceRetrieved(user, amount);

        // Act
        vm.prank(user);
        registry.withdrawAvailableBalance();

        // Assert
        assertEq(registry.getMemberAvailableBalance(user), 0, "member available balance should be 0 after withdraw");
        assertEq(
            address(user).balance,
            beforeWithdrawBalance + amount,
            "contract balance should increase by the withdrawn amount"
        );
    }

    function test_withdrawAvailableBalance_Revert_noAvailableBalanceToWithdraw() external {
        // Arrange
        uint256 privKey = uint256(1);
        address user = vm.addr(privKey);
        uint256 minimumDeposit = registry.getMinimumDepositById(defaultStream);
        vm.deal(user, minimumDeposit);

        vm.startBroadcast(user);
        registry.depositBond{value: minimumDeposit}(bytes32(privKey), defaultStream, defaultRole);
        registry.unsuscribeFromStream(defaultStream);
        vm.stopBroadcast();
        vm.prank(user);
        registry.withdrawAvailableBalance();

        // Assert
        vm.expectRevert(abi.encodeWithSelector(ICommitteeRegistry.NoAvailableBalanceToWithdraw.selector, user));

        // Act
        vm.prank(user);
        registry.withdrawAvailableBalance();
    }

    // The following test checks the integration of depositBond, unsuscribeFromStream, and withdrawAvailableBalance
    function test_Integration_depositBond_unsuscribeFromStream_withdrawAvailableBalance_every_stream() external {
        // Arrange
        uint256 privKey = uint256(1);
        address user = vm.addr(privKey);
        uint256 totalDeposited = 0;
        Role requestedRole = Role.Operator;

        // 1. Deposit in All Streams
        for (uint8 i = 0; i < uint8(StreamDenomination._10BTC); i++) {
            // Arrange
            StreamDenomination stream = StreamDenomination(i);

            CommitteeMember[] memory committeesCandidates = registry.getCommitteeCandidates(stream);
            uint256 candidatesAmountBeforeDeposit = committeesCandidates.length;

            // Determine the minimum bond required (getMinimumDepositById(stream))
            uint256 minimumDeposit = registry.getMinimumDepositById(stream);
            vm.deal(user, minimumDeposit);

            // Act
            vm.prank(user);
            registry.depositBond{value: minimumDeposit}(bytes32(privKey), stream, requestedRole);

            // Arrange
            totalDeposited += minimumDeposit;

            // Assert that preStaked[streamIndex] equals the deposited amount
            assertEq(
                registry.getMemberPreStakedBalance(user, stream),
                minimumDeposit,
                "member pre-staked should match the minimum deposit for stream"
            );
            // Assert that requestedRoles[stream] is set
            assertTrue(
                registry.getMemberRequestedRole(user, stream) == requestedRole,
                "member requested role should match the requested role for stream"
            );
            // Assert that available is still 0
            assertEq(
                registry.getMemberAvailableBalance(user),
                0,
                "member available balance should be 0 after deposit for stream"
            );
            // Assert that the member is listed in committeesCandidates[stream]
            committeesCandidates = registry.getCommitteeCandidates(stream);
            assertEq(
                candidatesAmountBeforeDeposit + 1,
                committeesCandidates.length,
                "candidates amount should increase by 1 after deposit for stream"
            );
        }

        // 2. Unsubscribe from All Streams
        for (uint8 i = 0; i < uint8(StreamDenomination._10BTC); i++) {
            // Arrange
            StreamDenomination stream = StreamDenomination(i);
            uint256 lastAvailableBalance = registry.getMemberAvailableBalance(user);
            uint256 moneyToBecomeAvailable = registry.getMemberPreStakedBalance(user, stream);
            CommitteeMember[] memory committeesCandidates = registry.getCommitteeCandidates(stream);
            uint256 candidatesAmountBeforeUnsuscribe = committeesCandidates.length;

            // Act
            vm.prank(user);
            registry.unsuscribeFromStream(stream);

            // Assert that preStaked[streamIndex] is now 0
            assertEq(
                registry.getMemberPreStakedBalance(user, stream),
                0,
                "member pre-staked should be 0 after unsuscribing for stream"
            );
            // Assert that requestedRoles[stream] == Role.None
            assertTrue(
                registry.getMemberRequestedRole(user, stream) == Role.None,
                "member requested role should be None after unsuscribing for stream"
            );
            // Assert that available increased by the correct bond amount
            assertEq(
                registry.getMemberAvailableBalance(user),
                lastAvailableBalance + moneyToBecomeAvailable,
                "member available balance should increase by the pre-staked amount after unsuscribing for stream"
            );
            // Assert that the user is removed from committeesCandidates[stream]
            committeesCandidates = registry.getCommitteeCandidates(stream);
            assertEq(
                candidatesAmountBeforeUnsuscribe - 1,
                committeesCandidates.length,
                "candidates amount should increase by 1 after deposit for stream"
            );
        }

        // 3. Withdraw Available Balance
        //Arrange
        // Record the user’s balance before calling withdrawAvailable
        uint256 beforeWithdrawBalance = address(user).balance;

        // Assert that available now equals the sum of all deposits
        assertEq(
            registry.getMemberAvailableBalance(user),
            totalDeposited,
            "member available balance should be equal to the total deposited amount"
        );

        // Act
        vm.prank(user);
        registry.withdrawAvailableBalance();

        // Assert that the user's available == 0
        assertEq(registry.getMemberAvailableBalance(user), 0, "member available balance should be 0 after withdraw");

        // Assert that the user’s balance increased accordingly
        assertEq(
            address(user).balance,
            beforeWithdrawBalance + totalDeposited,
            "user balance should increase by the total deposited amount"
        );
    }

    function test_selectCommittee_Success_3OP_7WT() external {
        // Arrange
        StreamDenomination denomination = StreamDenomination._0_01BTC;
        uint64 streamId = 1;
        setUpCommitteeMembers(
            registry.MIN_COMMITTEE_MEMBERS() - registry.MIN_OPERATORS(), registry.MIN_OPERATORS(), denomination
        );

        // Act
        CommitteeMember[] memory selectedMembers = registry.selectCommittee(streamId);

        // Assert - Verify committee has correct size
        assertEq(selectedMembers.length, registry.MIN_COMMITTEE_MEMBERS(), "Committee should have 10 members");

        // Count roles in selection
        uint256 watchtowerCount = 0;
        uint256 operatorCount = 0;
        for (uint256 i = 0; i < selectedMembers.length; i++) {
            if (selectedMembers[i].role == Role.Watchtower) watchtowerCount++;
            else if (selectedMembers[i].role == Role.Operator) operatorCount++;
        }

        // Verify correct role distribution
        assertEq(
            watchtowerCount,
            registry.MIN_COMMITTEE_MEMBERS() - registry.MIN_OPERATORS(),
            "Committee should have 7 watchtowers"
        );
        assertEq(operatorCount, registry.MIN_OPERATORS(), "Committee should have 7 operators");

        assertUniqueMembers(selectedMembers);
    }

    function assertUniqueMembers(CommitteeMember[] memory selectedMembers) internal pure {
        for (uint256 i = 0; i < selectedMembers.length; i++) {
            for (uint256 j = i + 1; j < selectedMembers.length; j++) {
                if (selectedMembers[i].index == selectedMembers[j].index) {
                    console2.log("i:", i);
                    console2.log("j:", j);
                    console2.log("selectedMembers[i].index:", selectedMembers[i].index);
                    console2.log("selectedMembers[j].index:", selectedMembers[j].index);
                }
                assertNotEq(
                    selectedMembers[i].index, selectedMembers[j].index, "There is a repeated member in selected members"
                );
            }
        }
    }

    function test_selectCommittee_Success_7OP_3WT() external {
        // Arrange
        StreamDenomination denomination = StreamDenomination._0_01BTC;
        uint64 streamId = 1;
        setUpCommitteeMembers(
            registry.MIN_WATCHTOWERS(), registry.MIN_COMMITTEE_MEMBERS() - registry.MIN_WATCHTOWERS(), denomination
        );

        // Act
        CommitteeMember[] memory selectedMembers = registry.selectCommittee(streamId);

        // Assert - Verify committee has correct size
        assertEq(selectedMembers.length, registry.MIN_COMMITTEE_MEMBERS(), "Committee should have 10 members");

        // Count roles in selection
        uint256 watchtowerCount = 0;
        uint256 operatorCount = 0;
        for (uint256 i = 0; i < selectedMembers.length; i++) {
            if (selectedMembers[i].role == Role.Watchtower) watchtowerCount++;
            else if (selectedMembers[i].role == Role.Operator) operatorCount++;
        }

        // Verify correct role distribution
        assertEq(watchtowerCount, registry.MIN_WATCHTOWERS(), "Committee should have 3 watchtowers");
        assertEq(
            operatorCount,
            registry.MIN_COMMITTEE_MEMBERS() - registry.MIN_WATCHTOWERS(),
            "Committee should have 7 operators"
        );

        assertUniqueMembers(selectedMembers);
    }

    function test_selectCommittee_ReturnsDifferentCommittees() external {
        // Arrange
        StreamDenomination denomination = StreamDenomination._0_01BTC;
        uint64 streamId = 1;
        setUpCommitteeMembers(registry.MIN_COMMITTEE_MEMBERS(), registry.MIN_COMMITTEE_MEMBERS(), denomination);

        // First selection with timestamp 1
        vm.warp(1);
        CommitteeMember[] memory selectedMembers1 = registry.selectCommittee(streamId);
        assertUniqueMembers(selectedMembers1);

        // Second selection with different timestamp
        vm.warp(1000);
        CommitteeMember[] memory selectedMembers2 = registry.selectCommittee(streamId);
        assertUniqueMembers(selectedMembers2);

        // Verify both selections have correct size
        assertEq(selectedMembers1.length, registry.MIN_COMMITTEE_MEMBERS(), "First committee should have 10 members");
        assertEq(selectedMembers2.length, registry.MIN_COMMITTEE_MEMBERS(), "Second committee should have 10 members");

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
        // Arrange
        StreamDenomination denomination = StreamDenomination._0_01BTC;
        uint64 streamId = 1;
        setUpCommitteeMembers(
            registry.MIN_WATCHTOWERS() - 1,
            registry.MIN_COMMITTEE_MEMBERS() - registry.MIN_WATCHTOWERS() + 1,
            denomination
        );

        // Assert that selectCommittee reverts with NotEnoughWatchtowers error
        vm.expectRevert(
            abi.encodeWithSelector(
                ICommitteeRegistry.NotEnoughWatchtowers.selector,
                registry.MIN_WATCHTOWERS(),
                registry.MIN_WATCHTOWERS() - 1
            )
        );

        registry.selectCommittee(streamId);
    }

    function test_selectCommittee_Revert_NotEnoughOperators() external {
        // Arrange
        StreamDenomination denomination = StreamDenomination._0_01BTC;
        uint64 streamId = 1;
        setUpCommitteeMembers(
            registry.MIN_COMMITTEE_MEMBERS() - registry.MIN_OPERATORS() + 1, registry.MIN_OPERATORS() - 1, denomination
        );

        // Assert that selectCommittee reverts with NotEnoughOperators error
        vm.expectRevert(
            abi.encodeWithSelector(
                ICommitteeRegistry.NotEnoughOperators.selector, registry.MIN_OPERATORS(), registry.MIN_OPERATORS() - 1
            )
        );

        registry.selectCommittee(streamId);
    }

    function test_selectCommittee_Revert_NotEnoughMembers() external {
        // Arrange
        StreamDenomination denomination = StreamDenomination._0_01BTC;
        uint64 streamId = 1;
        setUpCommitteeMembers(registry.MIN_WATCHTOWERS(), registry.MIN_OPERATORS(), denomination);
        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                ICommitteeRegistry.NotEnoughMembers.selector,
                registry.MIN_COMMITTEE_MEMBERS(),
                registry.MIN_OPERATORS() + registry.MIN_WATCHTOWERS()
            )
        );
        // Act
        registry.selectCommittee(streamId);
    }
}
