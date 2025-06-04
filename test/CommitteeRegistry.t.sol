// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {
    Role, Member, CommitteeMember, Committee, CommitteeRegistry, PendingCommittee
} from "src/CommitteeRegistry.sol";
import {ICommitteeRegistry} from "src/interfaces/ICommitteeRegistry.sol";
import {StreamDenomination, IStreamManager} from "src/interfaces/IStreamManager.sol";
import {ICommitteeRegistry} from "src/interfaces/ICommitteeRegistry.sol";
import {HelperContract} from "test/helpers/HelperContract.sol";
import {BtcHelper} from "src/libraries/BtcHelper.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

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

    function test_applyToStream_Revert_TooManyMembers() external {
        // Arrange
        uint256 MAX_MEMBERS_SIZE = registry.MAX_MEMBERS_SIZE();
        uint256 minimumDeposit = registry.getMinimumDeposit(DEFAULT_STREAM);
        // we already have 3 members registered in the setup
        for (uint16 i = 3; i < MAX_MEMBERS_SIZE; i++) {
            uint256 privKey = uint256(i);
            // Add balance to the user
            address user = vm.addr(privKey);
            bytes32 pubKey = generatePubKey(privKey);
            vm.deal(user, minimumDeposit);

            vm.startBroadcast(privKey);
            registry.applyToStream{value: minimumDeposit}(pubKey, DEFAULT_STREAM, DEFAULT_ROLE);
            vm.stopBroadcast();
        }

        // Assert
        vm.expectRevert(abi.encodeWithSelector(ICommitteeRegistry.TooManyMembers.selector, MAX_MEMBERS_SIZE));
        // Act
        registry.applyToStream{value: minimumDeposit}(generatePubKey(MAX_MEMBERS_SIZE), DEFAULT_STREAM, DEFAULT_ROLE);
    }

    function test_applyToStream_Success() external {
        // Arrange
        uint256 privKey = uint256(1);
        bytes32 pubKey = generatePubKey(privKey);
        address user = vm.addr(privKey);
        uint256 minimumDeposit = registry.getMinimumDeposit(DEFAULT_STREAM);
        vm.deal(user, minimumDeposit);

        CommitteeMember[] memory committeesCandidates = registry.getCommitteeCandidates(DEFAULT_STREAM);
        uint256 candidatesAmountBefore = committeesCandidates.length;

        // Check balances before
        uint256 userBalanceBefore = user.balance;
        uint256 contractBalanceBefore = address(registry).balance;

        // Assert member registered
        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.NewMember(pubKey);

        // Assert assert deposited bond
        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.NewSecurityBondDeposit(user, DEFAULT_STREAM, DEFAULT_ROLE, minimumDeposit);

        // Act
        vm.prank(user);
        registry.applyToStream{value: minimumDeposit}(pubKey, DEFAULT_STREAM, DEFAULT_ROLE);

        // Assert
        assertEq(registry.getMemberPublicKey(user), pubKey, "member public key should match the deposited key");
        assertTrue(
            registry.getMemberRequestedRole(user, DEFAULT_STREAM) == DEFAULT_ROLE,
            "member requested role should match the requested role"
        );
        assertEq(registry.getMemberAvailableBalance(user), 0, "member available balance should be 0");
        assertEq(
            registry.getMemberPreStakedBalance(user, DEFAULT_STREAM),
            minimumDeposit,
            "member pre-staked should match the minimum deposit"
        );

        committeesCandidates = registry.getCommitteeCandidates(DEFAULT_STREAM);
        uint256 candidatesAmountAfter = committeesCandidates.length;
        assertEq(candidatesAmountBefore + 1, candidatesAmountAfter, "candidates amount should increase by 1");
        assertTrue(
            (committeesCandidates[candidatesAmountAfter - 1].role == DEFAULT_ROLE),
            "candidate role should match requested role"
        );
        assertEq(
            committeesCandidates[candidatesAmountAfter - 1].index,
            registry.getMemberIndexByAddress(user),
            "candidate index should match member index"
        );
        // Check balances after
        uint256 userBalanceAfter = user.balance;
        uint256 contractBalanceAfter = address(registry).balance;

        assertEq(userBalanceBefore - userBalanceAfter, minimumDeposit, "user balance should decrease by deposit");
        assertEq(
            contractBalanceAfter - contractBalanceBefore, minimumDeposit, "contract balance should increase by deposit"
        );
    }

    function test_applyToStream_Success_two_users() external {
        uint256 privKey1 = uint256(1);
        bytes32 pubKey1 = generatePubKey(privKey1);
        address user1 = vm.addr(privKey1);
        uint256 privKey2 = uint256(2);
        bytes32 pubKey2 = generatePubKey(privKey2);
        address user2 = vm.addr(privKey2);
        step_applyToStreamForStream(user1, pubKey1, DEFAULT_STREAM, Role.Operator);
        step_applyToStreamForStream(user2, pubKey2, DEFAULT_STREAM, Role.Operator);
    }

    function test_applyToStream_Revert_PublicKeyMismatch() external {
        // Arrange
        uint256 privKey = uint256(1);
        bytes32 pubKey = generatePubKey(privKey);
        bytes32 differentPubKey = generatePubKey(privKey + 1);
        address user = vm.addr(privKey);
        uint256 minimumDeposit = registry.getMinimumDeposit(DEFAULT_STREAM);
        vm.deal(user, minimumDeposit);

        vm.prank(user);
        registry.applyToStream{value: minimumDeposit}(pubKey, DEFAULT_STREAM, Role.Operator);

        vm.deal(user, minimumDeposit);

        // Assert member already registered for stream
        vm.expectRevert(abi.encodeWithSelector(ICommitteeRegistry.PublicKeyMismatch.selector, pubKey, differentPubKey));

        // Act
        vm.prank(user);
        registry.applyToStream{value: minimumDeposit}(differentPubKey, StreamDenomination._0_01BTC, Role.Watchtower);
    }

    function test_applyToStream_Revert_memberAlreadyRegisteredForStream() external {
        // Arrange
        uint256 privKey = uint256(1);
        bytes32 pubKey = generatePubKey(privKey);
        address user = vm.addr(privKey);
        uint256 minimumDeposit = registry.getMinimumDeposit(DEFAULT_STREAM);
        vm.deal(user, minimumDeposit);

        vm.prank(user);
        registry.applyToStream{value: minimumDeposit}(pubKey, DEFAULT_STREAM, Role.Operator);

        vm.deal(user, minimumDeposit);

        // Assert member already registered for stream
        vm.expectRevert(
            abi.encodeWithSelector(
                ICommitteeRegistry.MemberAlreadyRegisteredForStream.selector,
                user,
                DEFAULT_STREAM,
                Role.Watchtower,
                Role.Operator
            )
        );

        // Act
        vm.prank(user);
        registry.applyToStream{value: minimumDeposit}(pubKey, DEFAULT_STREAM, Role.Watchtower);
    }

    function test_applyToStream_Revert_requestedNoneRoleForStream() external {
        // Arrange
        uint256 privKey = uint256(1);
        bytes32 pubKey = generatePubKey(privKey);
        address user = vm.addr(privKey);
        uint256 minimumDeposit = registry.getMinimumDeposit(DEFAULT_STREAM);
        vm.deal(user, minimumDeposit);

        // Assert requested none role for stream
        vm.expectRevert(abi.encodeWithSelector(ICommitteeRegistry.RequestedNoneRoleForStream.selector, DEFAULT_STREAM));

        // Act
        vm.prank(user);
        registry.applyToStream{value: minimumDeposit}(pubKey, DEFAULT_STREAM, Role.None);
    }

    function test_applyToStream_Revert_despositBondTooLow() external {
        // Arrange
        uint256 privKey = uint256(1);
        bytes32 pubKey = generatePubKey(privKey);
        address user = vm.addr(privKey);
        uint256 minimumDeposit = registry.getMinimumDeposit(DEFAULT_STREAM);
        vm.deal(user, minimumDeposit - 1);

        // Assert deposit bond too low
        vm.expectRevert(
            abi.encodeWithSelector(ICommitteeRegistry.DespositBondTooLow.selector, minimumDeposit - 1, minimumDeposit)
        );

        // Act
        vm.prank(user);
        registry.applyToStream{value: minimumDeposit - 1}(pubKey, DEFAULT_STREAM, DEFAULT_ROLE);
    }

    function test_unsubscribeFromStream_Success() external {
        // Arrange
        uint256 privKey = uint256(1);
        bytes32 pubKey = generatePubKey(privKey);
        address user = vm.addr(privKey);
        uint256 minimumDeposit = registry.getMinimumDeposit(DEFAULT_STREAM);
        vm.deal(user, minimumDeposit);
        vm.prank(user);
        registry.applyToStream{value: minimumDeposit}(pubKey, DEFAULT_STREAM, Role.Operator);
        CommitteeMember[] memory committeesCandidates = registry.getCommitteeCandidates(DEFAULT_STREAM);
        uint256 candidatesAmountBefore = committeesCandidates.length;

        // Assert
        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.MemberUnsubscribedFromStream(user, DEFAULT_STREAM);
        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.NewAvailableBalance(user, minimumDeposit);

        // Act
        vm.prank(user);
        registry.unsubscribeFromStream(DEFAULT_STREAM);

        // Assert
        assertEq(
            registry.getMemberAvailableBalance(user),
            minimumDeposit,
            "member available balance should match the minimum deposit"
        );
        assertEq(
            registry.getMemberPreStakedBalance(user, DEFAULT_STREAM),
            0,
            "member pre-staked should be 0 after unsuscribe"
        );
        assertTrue(
            registry.getMemberRequestedRole(user, DEFAULT_STREAM) == Role.None,
            "member requested role should be None after unsuscribe"
        );
        committeesCandidates = registry.getCommitteeCandidates(DEFAULT_STREAM);
        uint256 candidatesAmountAfter = committeesCandidates.length;
        assertEq(candidatesAmountBefore - 1, candidatesAmountAfter, "candidates amount should decrease by 1");
    }

    function test_unsubscribeFromStream_Revert_memberIsNotCandidateForStream() external {
        // Arrange
        uint256 privKey = uint256(1);
        bytes32 pubKey = generatePubKey(privKey);
        address user = vm.addr(privKey);
        uint256 minimumDeposit = registry.getMinimumDeposit(StreamDenomination._0_001BTC);
        vm.deal(user, minimumDeposit);
        vm.prank(user);
        registry.applyToStream{value: minimumDeposit}(pubKey, StreamDenomination._0_001BTC, Role.Operator);

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                ICommitteeRegistry.MemberIsNotCandidateForStream.selector, user, StreamDenomination._0_01BTC
            )
        );

        // Act
        vm.prank(user);
        registry.unsubscribeFromStream(StreamDenomination._0_01BTC);
    }

    function test_unsubscribeFromStream_Revert_nonRegisteredMember() external {
        // Arrange
        uint256 privKey = uint256(1);
        address user = vm.addr(privKey);

        // Assert
        vm.expectRevert(abi.encodeWithSelector(ICommitteeRegistry.NonRegisteredMember.selector, user));

        // Act
        vm.prank(user);
        registry.unsubscribeFromStream(DEFAULT_STREAM);
    }

    function test_withdrawAvailableBalance_Success() external {
        // Arrange
        uint256 privKey = uint256(1);
        bytes32 pubKey = generatePubKey(privKey);
        address user = vm.addr(privKey);
        uint256 minimumDeposit = registry.getMinimumDeposit(DEFAULT_STREAM);
        vm.deal(user, minimumDeposit);

        vm.startBroadcast(user);
        registry.applyToStream{value: minimumDeposit}(pubKey, DEFAULT_STREAM, DEFAULT_ROLE);
        registry.unsubscribeFromStream(DEFAULT_STREAM);
        vm.stopBroadcast();

        uint256 amount = registry.getMemberAvailableBalance(user);

        uint256 beforeWithdrawBalance = address(user).balance;
        uint256 contractBalanceBefore = address(registry).balance;

        // Assert
        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.AvailableBalanceRetrieved(user, amount);

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
        assertEq(
            address(registry).balance,
            contractBalanceBefore - amount,
            "user balance should decrease by the withdrawn amount"
        );
    }

    function test_withdrawAvailableBalance_Revert_noAvailableBalanceToWithdraw() external {
        // Arrange
        uint256 privKey = uint256(1);
        bytes32 pubKey = generatePubKey(privKey);
        address user = vm.addr(privKey);
        uint256 minimumDeposit = registry.getMinimumDeposit(DEFAULT_STREAM);
        vm.deal(user, minimumDeposit);

        vm.startBroadcast(user);
        registry.applyToStream{value: minimumDeposit}(pubKey, DEFAULT_STREAM, DEFAULT_ROLE);
        registry.unsubscribeFromStream(DEFAULT_STREAM);
        registry.withdrawAvailableBalance();
        vm.stopBroadcast();

        // Assert
        vm.expectRevert(abi.encodeWithSelector(ICommitteeRegistry.NoAvailableBalanceToWithdraw.selector, user));

        // Act
        vm.prank(user);
        registry.withdrawAvailableBalance();
    }

    function step_applyToStreamForStream(address user, bytes32 pubKey, StreamDenomination stream, Role requestedRole)
        internal
        returns (uint256)
    {
        // Arrange
        CommitteeMember[] memory committeesCandidates = registry.getCommitteeCandidates(stream);
        uint256 candidatesAmountBeforeDeposit = committeesCandidates.length;

        // Determine the minimum bond required (getMinimumDeposit(stream))
        uint256 minimumDeposit = registry.getMinimumDeposit(stream);
        vm.deal(user, minimumDeposit);

        // Act
        vm.prank(user);
        registry.applyToStream{value: minimumDeposit}(pubKey, stream, requestedRole);

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
            registry.getMemberAvailableBalance(user), 0, "member available balance should be 0 after deposit for stream"
        );
        // Assert that the member is listed in committeesCandidates[stream]
        committeesCandidates = registry.getCommitteeCandidates(stream);
        assertEq(
            candidatesAmountBeforeDeposit + 1,
            committeesCandidates.length,
            "candidates amount should increase by 1 after deposit for stream"
        );
        assertEq(
            committeesCandidates[committeesCandidates.length - 1].index,
            registry.getMemberIndexByAddress(user),
            "candidate index should match member index"
        );
        return minimumDeposit;
    }

    function step_unsubscribeFromStream(address user, StreamDenomination stream) internal {
        // Arrange
        uint256 lastAvailableBalance = registry.getMemberAvailableBalance(user);
        uint256 moneyToBecomeAvailable = registry.getMemberPreStakedBalance(user, stream);
        CommitteeMember[] memory committeesCandidates = registry.getCommitteeCandidates(stream);
        uint256 candidatesAmountBeforeUnsuscribe = committeesCandidates.length;

        // Act
        vm.prank(user);
        registry.unsubscribeFromStream(stream);

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

    // The following test checks the integration of applyToStream, unsubscribeFromStream, and withdrawAvailableBalance
    function test_Integration_applyToStream_unsubscribeFromStream_withdrawAvailableBalance_every_stream() external {
        // Arrange
        uint256 privKey = uint256(1);
        bytes32 pubKey = generatePubKey(privKey);
        address user = vm.addr(privKey);
        uint256 totalDeposited = 0;
        Role requestedRole = Role.Operator;

        // 1. Deposit in All Streams
        for (uint8 i = 0; i < uint8(StreamDenomination._10BTC); i++) {
            totalDeposited += step_applyToStreamForStream(user, pubKey, StreamDenomination(i), requestedRole);
        }

        // 2. Unsubscribe from All Streams
        for (uint8 i = 0; i < uint8(StreamDenomination._10BTC); i++) {
            step_unsubscribeFromStream(user, StreamDenomination(i));
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
        setup_committeeMembers(
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
        setup_committeeMembers(
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
        setup_committeeMembers(registry.MIN_COMMITTEE_MEMBERS(), registry.MIN_COMMITTEE_MEMBERS(), denomination);

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
        setup_committeeMembers(
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
        setup_committeeMembers(
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
        setup_committeeMembers(registry.MIN_WATCHTOWERS(), registry.MIN_OPERATORS(), denomination);
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
        vm.expectRevert(abi.encodeWithSelector(ICommitteeRegistry.CommitteeIsNotPending.selector, 0));
        // Act
        registry.getPendingCommittee(0);
    }

    function test_createCommittee_Success() external {
        // Arrange
        (Committee memory expectedCommittee, uint64 streamId) = setup_committee();

        // Assert
        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.NewPendingCommittee(streamId, expectedCommittee);

        // Act
        // This should create a committee as pending
        vm.prank(address(pm));
        registry.createCommittee(streamId);

        (Committee memory committee, uint256 createdAt, uint256 missingData) = registry.getPendingCommittee(streamId);
        // Assert
        assertEqCommittee(expectedCommittee, committee, "Committee should be equeals");
        assertNotEq(createdAt, 0, "Created at should not be 0");
        assertEq(missingData, registry.MIN_COMMITTEE_MEMBERS(), "Missing data should be equal to MIN_COMMITTEE_MEMBERS");
    }

    function test_createCommittee_Success_AlreadyPendingButNotExpired() external {
        // Arrange
        (, uint64 streamId) = setup_createCommittee();
        (Committee memory pendingCommittee, uint256 createdAt, uint256 missingData) =
            registry.getPendingCommittee(streamId);
        vm.recordLogs();

        // createCommittee called by pegManager should do nothing if pending committee is not expired
        // Act
        vm.prank(address(pm));
        registry.createCommittee(streamId);

        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertEq(logs.length, 0, "Expected no events to be emitted");

        (Committee memory pendingCommitteeAfterCall, uint256 createdAtAfterCall, uint256 missingDataAfterCall) =
            registry.getPendingCommittee(streamId);

        assertEq(createdAt, createdAtAfterCall, "Pending committee should not change");
        assertEq(missingData, missingDataAfterCall, "Pending committee should not change");
        assertEq(
            pendingCommittee.aggregatedKey,
            pendingCommitteeAfterCall.aggregatedKey,
            "Pending committee should not change"
        );
        assertEqCommitteeMembers(
            pendingCommittee.memberIndexesAndRoles,
            pendingCommitteeAfterCall.memberIndexesAndRoles,
            "Create committee should not change members"
        );
    }

    function test_getPendingCommittee_Success() external {
        // Arrange
        (Committee memory expectedCommittee, uint64 streamId) = setup_createCommittee();

        // Act
        (Committee memory committee, uint256 expiredAt, uint256 missingData) = registry.getPendingCommittee(streamId);

        // Assert
        assertEqCommittee(committee, expectedCommittee, "get pending committee");
        assertNotEq(expiredAt, 0);
        assertEq(missingData, registry.MIN_COMMITTEE_MEMBERS());
    }

    function test_depositMemberInfoForCommittee_Success() external {
        // Arrange
        (Committee memory expectedCommittee, uint64 streamId) = setup_createCommittee();
        expectedCommittee.aggregatedKey = COMMITEE_1_PUB_KEY;

        // Act
        vm.prank(vm.addr(1));
        registry.depositMemberInfoForCommittee(streamId, COMMITEE_1_PUB_KEY);

        // Assert
        (Committee memory committee, uint256 expiredAt, uint256 missingData) = registry.getPendingCommittee(streamId);
        assertEqCommittee(committee, expectedCommittee, "get pending committee");
        assertNotEq(expiredAt, 0);
        assertEq(missingData, registry.MIN_COMMITTEE_MEMBERS() - 1);
    }

    function test_depositMemberInfoForCommittee_Revert_InvalidAgregatedKey() external {
        // Arrange
        (, uint64 streamId) = setup_createCommittee();

        // Assert
        vm.expectRevert(abi.encodeWithSelector(ICommitteeRegistry.InvalidAgregatedKey.selector));

        // Act
        vm.prank(vm.addr(1));
        registry.depositMemberInfoForCommittee(streamId, bytes32(0));
    }

    function test_depositMemberInfoForCommittee_WrongCommitteeKey() external {
        // Arrange
        (Committee memory expectedCommittee, uint64 streamId) = setup_createCommittee();
        setup_depositMemberInfo(streamId, vm.addr(1));

        // Assert
        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.NewPendingCommittee(streamId, expectedCommittee);

        // Act
        // Second member deposit wrong committee aggregated key, so discard current pending committee a create a new one.
        vm.prank(vm.addr(2));
        registry.depositMemberInfoForCommittee(streamId, COMMITEE_2_PUB_KEY);

        // Assert
        (Committee memory committee, uint256 expiredAt, uint256 missingData) = registry.getPendingCommittee(streamId);
        assertEqCommittee(committee, expectedCommittee, "get pending committee");
        assertNotEq(expiredAt, 0);
        assertEq(missingData, registry.MIN_COMMITTEE_MEMBERS());
    }

    function test_depositMemberInfoForCommittee_Success_CompleteCommittee() external {
        // Arrange
        (Committee memory expectedCommittee, uint64 streamId) = setup_createCommittee();
        expectedCommittee.aggregatedKey = COMMITEE_1_PUB_KEY;
        setup_depositMemberInfo_MultipleMembers(streamId, 0, registry.MIN_COMMITTEE_MEMBERS() - 2);

        // Assert
        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.NewCommittee(
            92458281274488595289803937127152923398167637295201432141969818930235769911599, expectedCommittee
        );

        // Act
        // Member address is vm.address(memberIndex + 1);
        vm.prank(vm.addr(registry.MIN_COMMITTEE_MEMBERS()));
        registry.depositMemberInfoForCommittee(streamId, COMMITEE_1_PUB_KEY);
    }

    function test_getPendingCommittee_Revert_CommitteeIsNotPending_AfterCompleteCommittee() external {
        // Arrange
        (, uint64 streamId) = setup_createCommittee();
        setup_depositMemberInfo_MultipleMembers(streamId, 0, registry.MIN_COMMITTEE_MEMBERS() - 1);

        // Assert
        vm.expectRevert(abi.encodeWithSelector(ICommitteeRegistry.CommitteeIsNotPending.selector, streamId));
        // Act
        registry.getPendingCommittee(streamId);
    }

    function test_isPendingCommitteeExpired_False_BeforeCreateCommittee() external view {
        // Act
        bool isCommitteePendingExpired = registry.isPendingCommitteeExpired(0);
        // Assert
        // There is no pending committee so it's not expired
        assertFalse(isCommitteePendingExpired, "pending committee is expired");
    }

    function test_isPendingCommitteeExpired_False_AfterCreateCommittee() external {
        // Arrange
        (Committee memory expectedCommittee, uint64 streamId) = setup_createCommittee();
        expectedCommittee.aggregatedKey = COMMITEE_1_PUB_KEY;
        setup_depositMemberInfo(streamId, vm.addr(1));

        // Act
        bool isCommitteePendingExpired = registry.isPendingCommitteeExpired(streamId);

        // Assert
        // There is pending committee and it's not expired
        assertFalse(isCommitteePendingExpired, "pending committee is expired");
    }

    function test_isPendingCommitteeExpired_False_AfterSomeSeconds() external {
        // Arrange
        (Committee memory expectedCommittee, uint64 streamId) = setup_createCommittee();
        expectedCommittee.aggregatedKey = COMMITEE_1_PUB_KEY;
        setup_depositMemberInfo(streamId, vm.addr(1));
        vm.warp(block.timestamp + 60 seconds); // warp time but amount of time is not enough to expire the committee

        // Act
        bool isCommitteePendingExpired = registry.isPendingCommitteeExpired(streamId);

        // Assert
        // There is pending committee and it's not expired
        assertFalse(isCommitteePendingExpired, "pending committee is expired");
    }

    function test_isPendingCommitteeExpired_True_ChangingTimeout() external {
        // Arrange
        (, uint64 streamId) = setup_createCommittee();
        vm.warp(block.timestamp + 60 seconds); // warp time to make committee expired

        // Act
        vm.prank(address(registry.owner()));
        registry.setPendingCommitteeTimeout(30 seconds);

        // Assert
        bool isCommitteePendingExpired = registry.isPendingCommitteeExpired(streamId);
        assertTrue(isCommitteePendingExpired, "pending committee is not expired");
    }

    function test_isPendingCommitteeExpired_True_AfterTimeout() external {
        // Arrange
        (, uint64 streamId) = setup_createCommittee();
        uint256 timeout = registry.pendingCommitteeTimeout();
        vm.warp(block.timestamp + timeout + 1 seconds); // warp time to make committee expired

        // Act
        bool isCommitteePendingExpired = registry.isPendingCommitteeExpired(streamId);

        // Assert
        // There is pending committee and it's expired
        assertTrue(isCommitteePendingExpired, "pending committee is not expired");
    }

    function test_createCommittee_Success_AfterExpiredCommittee() external {
        // Arrange
        (Committee memory expectedCommittee, uint64 streamId) = setup_createCommitteeAndExpire();

        // Assert
        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.NewPendingCommittee(streamId, expectedCommittee);

        // Act
        vm.prank(address(pm));
        registry.createCommittee(streamId);

        // Assert
        (Committee memory committee, uint256 expiredAt, uint256 missingData) = registry.getPendingCommittee(streamId);
        assertEqCommittee(committee, expectedCommittee, "get pending committee");
        assertNotEq(expiredAt, 0);
        assertEq(missingData, registry.MIN_COMMITTEE_MEMBERS());
    }

    function test_depositMemberInfoForCommittee_Success_CompleteCommitteeOnExpiredCommittee() external {
        // Having an expired committee does not prevent members to still deposit their data
        // Arrange
        (Committee memory expectedCommittee, uint64 streamId) = setup_createCommittee();
        uint256 timeout = registry.pendingCommitteeTimeout();
        vm.warp(block.timestamp + timeout + 1 seconds); // warp time to make committee expired
        expectedCommittee.aggregatedKey = COMMITEE_1_PUB_KEY;
        setup_depositMemberInfo_MultipleMembers(streamId, 0, registry.MIN_COMMITTEE_MEMBERS() - 2);

        // Assert
        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.NewCommittee(
            92458281274488595289803937127152923398167637295201432141969818930235769911599, expectedCommittee
        );

        // Act
        // Member address is vm.address(memberIndex + 1);
        vm.prank(vm.addr(registry.MIN_COMMITTEE_MEMBERS()));
        registry.depositMemberInfoForCommittee(streamId, COMMITEE_1_PUB_KEY);

        // Assert
        vm.expectRevert(abi.encodeWithSelector(ICommitteeRegistry.CommitteeIsNotPending.selector, streamId));
        // Act
        registry.getPendingCommittee(streamId);
    }

    function test_setPendingCommitteeTimeout_Success() external {
        // Arrange
        uint256 newTimeout = registry.pendingCommitteeTimeout() / 2;

        // Act
        vm.prank(address(registry.owner()));
        registry.setPendingCommitteeTimeout(newTimeout);

        // Assert
        assertEq(registry.pendingCommitteeTimeout(), newTimeout, "Pending committee timeout should be updated");
    }

    function test_setPendingCommitteeTimeout_Revert_OwnableUnauthorizedAccount() external {
        // Arrange
        uint256 newTimeout = registry.pendingCommitteeTimeout() / 2;

        // Assert
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));

        // Act
        registry.setPendingCommitteeTimeout(newTimeout);
    }

    function test_setPendingCommitteeTimeout_Revert_InvalidZeroTimeout() external {
        address owner = registry.owner();

        // Assert
        vm.expectRevert(abi.encodeWithSelector(ICommitteeRegistry.InvalidZeroTimeout.selector));

        // Act
        vm.prank(address(owner));
        registry.setPendingCommitteeTimeout(0);
    }

    function test_createCommittee_UnauthorizedAccount() external {
        // Assert
        vm.expectRevert(abi.encodeWithSelector(ICommitteeRegistry.UnauthorizedAccount.selector, address(this)));

        // Act
        registry.createCommittee(0);
    }

    function test_getMemberPublicKey_Revert_NonRegisteredMember() external {
        // Arrange
        address user = vm.addr(uint256(100));

        // Assert
        vm.expectRevert(abi.encodeWithSelector(ICommitteeRegistry.NonRegisteredMember.selector, user));

        // Act
        registry.getMemberPublicKey(user);
    }

    function test_getMemberRequestedRole_Revert_NonRegisteredMember() external {
        // Arrange
        address user = vm.addr(uint256(100));

        // Assert
        vm.expectRevert(abi.encodeWithSelector(ICommitteeRegistry.NonRegisteredMember.selector, user));

        // Act
        registry.getMemberRequestedRole(user, DEFAULT_STREAM);
    }

    function test_getMemberAvailableBalance_Revert_NonRegisteredMember() external {
        // Arrange
        address user = vm.addr(uint256(100));

        // Assert
        vm.expectRevert(abi.encodeWithSelector(ICommitteeRegistry.NonRegisteredMember.selector, user));

        // Act
        registry.getMemberAvailableBalance(user);
    }

    function test_getMemberPreStakedBalance_Revert_NonRegisteredMember() external {
        // Arrange
        address user = vm.addr(uint256(100));

        // Assert
        vm.expectRevert(abi.encodeWithSelector(ICommitteeRegistry.NonRegisteredMember.selector, user));

        // Act
        registry.getMemberPreStakedBalance(user, DEFAULT_STREAM);
    }

    function test_getMemberStakedBalance_Revert_NonRegisteredMember() external {
        // Arrange
        address user = vm.addr(uint256(100));

        // Assert
        vm.expectRevert(abi.encodeWithSelector(ICommitteeRegistry.NonRegisteredMember.selector, user));

        // Act
        registry.getMemberStakedBalance(user, DEFAULT_STREAM, 0);
    }

    function test_registerMember_Success() external {
        // Arrange
        uint256 privKey = uint256(1);
        bytes32 pubKey = generatePubKey(privKey);
        address user = vm.addr(privKey);

        // Assert
        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.NewMember(pubKey);

        // Act
        vm.prank(user);
        registry.registerMember(pubKey);

        // Assert
        assertEq(registry.getMemberPublicKey(user), pubKey, "member public key should match the registered key");
        assertEq(registry.getMemberIndexByAddress(user), 3, "member index should be 3 after registration");
        assertEq(registry.getMemberAvailableBalance(user), 0, "member available balance should be 0 after registration");
        for (uint64 i = 0; i < uint8(StreamDenomination._10BTC); i++) {
            assertEq(
                registry.getMemberPreStakedBalance(user, StreamDenomination(i)),
                0,
                "member pre-staked should be 0 after registration for stream"
            );
            assertEq(
                registry.getMemberStakedBalance(user, StreamDenomination(i), 0),
                0,
                "member staked balance should be 0 after registration for stream"
            );
            assertTrue(
                registry.getMemberRequestedRole(user, StreamDenomination(i)) == Role.None,
                "member requested role should be None after registration for stream"
            );
        }
    }

    function test_registerCandidateToStream_Success() external {
        // Arrange
        uint256 privKey = uint256(1);
        setup_registerMember(privKey);
        address user = vm.addr(privKey);
        uint256 minimumDeposit = registry.getMinimumDeposit(DEFAULT_STREAM);

        // Act
        vm.prank(user);
        registry.registerCandidateToStream(user, DEFAULT_STREAM, DEFAULT_ROLE, minimumDeposit);

        // Assert
        assertEq(registry.getMemberAvailableBalance(user), 0, "member available balance should be 0 after registration");
        assertEq(
            registry.getMemberPreStakedBalance(user, DEFAULT_STREAM),
            minimumDeposit,
            "member pre-staked should match the minimum deposit for stream"
        );
        for (uint64 i = 0; i < uint8(StreamDenomination._10BTC); i++) {
            if (i == uint8(DEFAULT_STREAM)) {
                assertTrue(
                    registry.getMemberRequestedRole(user, StreamDenomination(i)) == DEFAULT_ROLE,
                    "member requested role should match the requested role for stream"
                );
            } else {
                assertTrue(
                    registry.getMemberRequestedRole(user, StreamDenomination(i)) == Role.None,
                    "member requested role should be None for other streams"
                );
                uint256 preStakedBalance = registry.getMemberPreStakedBalance(user, StreamDenomination(i));
                assertEq(preStakedBalance, 0, "member pre-staked should be 0 for other streams");
            }
            assertEq(
                registry.getMemberStakedBalance(user, StreamDenomination(i), 0),
                0,
                "member staked balance should be 0 for all streams after registration for a stream"
            );
        }
        CommitteeMember[] memory committeesCandidates = registry.getCommitteeCandidates(DEFAULT_STREAM);
        assertTrue(
            (committeesCandidates[committeesCandidates.length - 1].role == DEFAULT_ROLE),
            "candidate role should match requested role"
        );
        assertEq(
            committeesCandidates[committeesCandidates.length - 1].index,
            registry.getMemberIndexByAddress(user),
            "candidate index should match member index"
        );
    }

    function test_registerCandidateToStream_Revert_NonRegisteredMember() external {
        // Arrange
        uint256 privKey = uint256(1);
        address user = vm.addr(privKey);
        uint256 minimumDeposit = registry.getMinimumDeposit(DEFAULT_STREAM);
        vm.deal(user, minimumDeposit);

        // Assert
        vm.expectRevert(abi.encodeWithSelector(ICommitteeRegistry.NonRegisteredMember.selector, user));

        // Act
        vm.prank(user);
        registry.registerCandidateToStream(user, DEFAULT_STREAM, DEFAULT_ROLE, minimumDeposit);
    }

    function test_getMinimumDeposit_Success() external view {
        // Arrange
        uint64[5] memory denominations = [
            uint64(100_000), // 0.001 BTC
            uint64(1_000_000), // 0.01 BTC
            uint64(10_000_000), // 0.1 BTC
            uint64(100_000_000), // 1 BTC
            uint64(1_000_000_000) // 10 BTC
        ];

        for (uint8 i = 0; i < uint8(StreamDenomination._10BTC); i++) {
            // Act
            uint256 minDeposit = registry.getMinimumDeposit(StreamDenomination(i));

            // Assert
            uint64 denomination = denominations[i];
            assertEq(
                minDeposit,
                BtcHelper.satoshiToWei(denomination) / 10,
                "Error SecurityBond min deposit should be equal to the denomination"
            );
        }
    }

    function test_restartPendingCommittee_Revert_CommitteeIsNotPending() external {
        // Assert
        vm.expectRevert(abi.encodeWithSelector(ICommitteeRegistry.CommitteeIsNotPending.selector, 0));

        // Act
        registry.restartPendingCommittee(0);
    }

    function test_restartPendingCommittee_Revert_PendingCommitteeNotExpired() external {
        // Arrange
        (, uint64 streamId) = setup_createCommittee();
        setup_depositMemberInfo(streamId, vm.addr(1));

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(ICommitteeRegistry.PendingCommitteeNotExpired.selector, streamId, 1000, 87400)
        );

        // Act
        registry.restartPendingCommittee(streamId);
    }

    function test_restartPendingCommittee_Success() external {
        // Arrange
        (Committee memory expectedCommittee, uint64 streamId) = setup_createCommitteeAndExpire();

        // Assert
        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.NewPendingCommittee(streamId, expectedCommittee);

        // Act
        registry.restartPendingCommittee(streamId);

        // Assert
        (Committee memory committee, uint256 createdAt, uint256 missingData) = registry.getPendingCommittee(streamId);
        assertEqCommittee(committee, expectedCommittee, "get pending committee after restart");
        assertNotEq(createdAt, 0);
        assertEq(missingData, registry.MIN_COMMITTEE_MEMBERS(), "missing data should be equal to min committee members");
    }
}
