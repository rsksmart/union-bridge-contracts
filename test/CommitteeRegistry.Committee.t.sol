// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {CommitteeRegistry} from "src/CommitteeRegistry.sol";
import {
    ICommitteeRegistry,
    PendingCommitteeStatus,
    PublicKeyRegistration,
    Role,
    CommitteeMember,
    Committee,
    PendingCommittee
} from "src/interfaces/ICommitteeRegistry.sol";
import {StreamDenomination, IStreamManager, Stream} from "src/interfaces/IStreamManager.sol";
import {HelperContract} from "test/helpers/HelperContract.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Constants} from "src/libraries/Constants.sol";

contract TestCommitteeRegistry is Test, HelperContract {
    function setUp() external {
        runTestDeployScript();
    }

    function test_shouldCreateCommittee_AfterInit() external view {
        for (uint64 i = 0; i <= uint64(StreamDenomination._10BTC); i++) {
            assertTrue(
                registry.shouldCreateCommitteeHarness(i), "shouldCreateCommittee should be true after initialization"
            );
        }
    }

    function test_setCommitteeMinWatchtowers_Success() external {
        // Arrange
        uint256 newMinWatchtowers = registry.minCommitteeWatchtowers() / 2;

        // Assert
        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.CommitteeMinWatchtowersUpdated(newMinWatchtowers);

        // Act
        vm.prank(address(registry.owner()));
        registry.setCommitteeMinWatchtowers(newMinWatchtowers);

        // Assert
        assertEq(registry.minCommitteeWatchtowers(), newMinWatchtowers, "Committee min watchtowers should be updated");
    }

    function test_setCommitteeMinWatchtowers_Revert_OwnableUnauthorizedAccount() external {
        // Arrange
        uint256 newMinWatchtowers = registry.minCommitteeWatchtowers() / 2;

        // Assert
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));

        // Act
        registry.setCommitteeMinWatchtowers(newMinWatchtowers);
    }

    function test_setCommitteeMinWatchtowers_Revert_InvalidZeroValue() external {
        address owner = registry.owner();

        // Assert
        vm.expectRevert(abi.encodeWithSelector(ICommitteeRegistry.InvalidZeroValue.selector));

        // Act
        vm.prank(address(owner));
        registry.setCommitteeMinWatchtowers(0);
    }

    function test_setCommitteeMinOperators_Success() external {
        // Arrange
        uint256 newMinOperators = registry.minCommitteeOperators() / 2;

        // Assert
        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.CommitteeMinOperatorsUpdated(newMinOperators);

        // Act
        vm.prank(address(registry.owner()));
        registry.setCommitteeMinOperators(newMinOperators);

        // Assert
        assertEq(registry.minCommitteeOperators(), newMinOperators, "Committee min operators should be updated");
    }

    function test_setCommitteeMinOperators_Revert_OwnableUnauthorizedAccount() external {
        // Arrange
        uint256 newMinOperators = registry.minCommitteeOperators() / 2;

        // Assert
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));

        // Act
        registry.setCommitteeMinOperators(newMinOperators);
    }

    function test_setCommitteeMinOperators_Revert_InvalidZeroValue() external {
        address owner = registry.owner();

        // Assert
        vm.expectRevert(abi.encodeWithSelector(ICommitteeRegistry.InvalidZeroValue.selector));

        // Act
        vm.prank(address(owner));
        registry.setCommitteeMinOperators(0);
    }

    function test_setCommitteeMinMembers_Success() external {
        // Arrange
        uint256 newMinMembers = registry.minCommitteeMembers() + 1;

        // Assert
        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.CommitteeMinMembersUpdated(newMinMembers);

        // Act
        vm.prank(address(registry.owner()));
        registry.setCommitteeMinMembers(newMinMembers);

        // Assert
        assertEq(registry.minCommitteeMembers(), newMinMembers, "Committee min members should be updated");
    }

    function test_setCommitteeMinMembers_Revert_OwnableUnauthorizedAccount() external {
        // Arrange
        uint256 newMinMembers = registry.minCommitteeMembers() + 1;

        // Assert
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));

        // Act
        registry.setCommitteeMinMembers(newMinMembers);
    }

    function test_setCommitteeMinMembers_Revert_InvalidZeroValue() external {
        address owner = registry.owner();

        // Assert
        vm.expectRevert(abi.encodeWithSelector(ICommitteeRegistry.InvalidZeroValue.selector));

        // Act
        vm.prank(address(owner));
        registry.setCommitteeMinMembers(0);
    }

    function test_setCommitteeMinMembers_Revert_InvalidMinMembers() external {
        address owner = registry.owner();
        uint256 minWatchtowers = registry.minCommitteeWatchtowers();
        uint256 minOperators = registry.minCommitteeOperators();
        uint256 invalidMinMembers = minWatchtowers + minOperators - 1;

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                ICommitteeRegistry.InvalidMinMembers.selector, invalidMinMembers, minWatchtowers, minOperators
            )
        );

        // Act
        vm.prank(address(owner));
        registry.setCommitteeMinMembers(invalidMinMembers);
    }

    function test_getCommittee_Success() external {
        // Arrange
        (Committee memory expectedCommittee, uint64 streamId) = setup_completeCommittee();

        // Act
        Committee memory committee = registry.getCommittee(COMMITTEE_ID_STREAM_1_PACKET_0);
        // Assert
        assertEqCommittee(expectedCommittee, committee, "Committees are not equal");
        assertFalse(
            registry.shouldCreateCommitteeHarness(streamId),
            "shouldCreateCommittee should be false after setup completeCommittee call"
        );

        for (uint64 i = 0; i <= uint64(StreamDenomination._10BTC); i++) {
            if (i != streamId) {
                assertTrue(
                    registry.shouldCreateCommitteeHarness(i),
                    "shouldCreateCommittee should be true after initialization"
                );
            }
        }
    }

    function test_getCommitteeMembers_Success() external {
        // Arrange
        (Committee memory expectedCommittee,) = setup_completeCommittee();

        // Act
        CommitteeMember[] memory members = registry.getCommitteeMembers(COMMITTEE_ID_STREAM_1_PACKET_0);
        // Assert
        assertEqCommitteeMembers(expectedCommittee.memberIndexesAndRoles, members, "Member list are not equal");
    }

    function test_selectCommittee_Success_MinOperators() external {
        // Arrange
        StreamDenomination denomination = StreamDenomination._0_01BTC;
        uint64 streamId = 1;
        uint256 numOperators = registry.minCommitteeOperators();
        uint256 numWatchtowers = registry.minCommitteeMembers() - numOperators;
        setup_registerNewMembers(numWatchtowers, numOperators, denomination);

        // Act
        (CommitteeMember[] memory selectedMembers, PendingCommitteeStatus status) = registry.selectCommittee(streamId);

        // Assert - Verify status and committee has correct size
        assertTrue(status == PendingCommitteeStatus.SUCCESS, "Committee selection should be successful");
        assertEq(selectedMembers.length, registry.minCommitteeMembers(), "Committee should have 10 members");

        // Count roles in selection
        uint256 watchtowerCount = 0;
        uint256 operatorCount = 0;
        for (uint256 i = 0; i < selectedMembers.length; i++) {
            if (selectedMembers[i].role == Role.WATCHTOWER) watchtowerCount++;
            else if (selectedMembers[i].role == Role.OPERATOR) operatorCount++;
        }

        // Verify correct role distribution
        assertEq(
            watchtowerCount,
            registry.minCommitteeMembers() - registry.minCommitteeOperators(),
            "Committee should have 7 watchtowers"
        );
        assertEq(operatorCount, registry.minCommitteeOperators(), "Committee should have 7 operators");

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

    function test_selectCommittee_Success_MinWatchtowers() external {
        // Arrange
        StreamDenomination denomination = StreamDenomination._0_01BTC;
        uint64 streamId = 1;
        uint256 numWatchtowers = registry.minCommitteeWatchtowers();
        uint256 numOperators = registry.minCommitteeMembers() - numWatchtowers;
        setup_registerNewMembers(numWatchtowers, numOperators, denomination);

        // Act
        (CommitteeMember[] memory selectedMembers, PendingCommitteeStatus status) = registry.selectCommittee(streamId);

        // Assert - Verify status and committee has correct size
        assertTrue(status == PendingCommitteeStatus.SUCCESS, "Committee selection should be successful");
        assertEq(selectedMembers.length, registry.minCommitteeMembers(), "Committee should have 10 members");

        // Count roles in selection
        uint256 watchtowerCount = 0;
        uint256 operatorCount = 0;
        for (uint256 i = 0; i < selectedMembers.length; i++) {
            if (selectedMembers[i].role == Role.WATCHTOWER) watchtowerCount++;
            else if (selectedMembers[i].role == Role.OPERATOR) operatorCount++;
        }

        // Verify correct role distribution
        assertEq(watchtowerCount, registry.minCommitteeWatchtowers(), "Committee should have 3 watchtowers");
        assertEq(
            operatorCount,
            registry.minCommitteeMembers() - registry.minCommitteeWatchtowers(),
            "Committee should have 7 operators"
        );

        assertUniqueMembers(selectedMembers);
    }

    function test_selectCommittee_ReturnsDifferentCommittees() external {
        // Arrange
        StreamDenomination denomination = StreamDenomination._0_01BTC;
        uint64 streamId = 1;
        uint256 numWachtowers = registry.minCommitteeWatchtowers();
        uint256 numOperators = registry.minCommitteeMembers();
        setup_registerNewMembers(numWachtowers, numOperators, denomination);

        // First selection with timestamp 1
        vm.warp(1);
        (CommitteeMember[] memory selectedMembers1, PendingCommitteeStatus status1) = registry.selectCommittee(streamId);
        assertTrue(status1 == PendingCommitteeStatus.SUCCESS, "Committee selection should be successful");
        assertUniqueMembers(selectedMembers1);

        // Second selection with different timestamp
        vm.warp(1000);
        (CommitteeMember[] memory selectedMembers2, PendingCommitteeStatus status2) = registry.selectCommittee(streamId);
        assertTrue(status2 == PendingCommitteeStatus.SUCCESS, "Committee selection should be successful");
        assertUniqueMembers(selectedMembers2);

        // Verify both selections have correct size
        assertEq(selectedMembers1.length, registry.minCommitteeMembers(), "First committee should have 10 members");
        assertEq(selectedMembers2.length, registry.minCommitteeMembers(), "Second committee should have 10 members");

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
        uint256 numWatchtowers = registry.minCommitteeWatchtowers() - 1;
        uint256 numOperators = registry.minCommitteeMembers() - numWatchtowers + 1;
        setup_registerNewMembers(numWatchtowers, numOperators, denomination);

        // Assert that selectCommittee reverts with MissingWatchtowers event
        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.MissingWatchtowers(denomination, registry.minCommitteeWatchtowers(), 1);

        // Act
        (CommitteeMember[] memory members, PendingCommitteeStatus status) = registry.selectCommittee(streamId);
        // Assert
        assertTrue(
            status == PendingCommitteeStatus.NOT_ENOUGH_WATCHTOWERS,
            "Committee selection should fail due to not enough watchtowers"
        );
        assertEq(members.length, 0, "No members should be selected due to not enough members");
        assertTrue(
            registry.shouldCreateCommitteeHarness(streamId),
            "Should be able to create committee after not enough watchtowers"
        );
    }

    function test_selectCommittee_Revert_NotEnoughOperators() external {
        // Arrange
        StreamDenomination denomination = StreamDenomination._0_01BTC;
        uint64 streamId = 1;
        uint256 numOperators = registry.minCommitteeOperators() - 1;
        uint256 numWatchtowers = registry.minCommitteeMembers() - numOperators + 1;
        setup_registerNewMembers(numWatchtowers, numOperators, denomination);

        // Assert that selectCommittee reverts with MissingOperators event
        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.MissingOperators(denomination, registry.minCommitteeOperators(), 1);

        // Act
        (CommitteeMember[] memory members, PendingCommitteeStatus status) = registry.selectCommittee(streamId);
        // Assert
        assertTrue(
            status == PendingCommitteeStatus.NOT_ENOUGH_OPERATORS,
            "Committee selection should fail due to not enough operators"
        );
        assertEq(members.length, 0, "No members should be selected due to not enough members");
        assertTrue(
            registry.shouldCreateCommitteeHarness(streamId),
            "Should be able to create committee after not enough watchtowers"
        );
    }

    function test_selectCommittee_Revert_NotEnoughMembers() external {
        // Arrange
        StreamDenomination denomination = StreamDenomination._0_01BTC;
        uint64 streamId = 1;
        uint256 numOperators = registry.minCommitteeOperators();
        uint256 numWatchtowers = registry.minCommitteeWatchtowers();
        setup_registerNewMembers(numWatchtowers, numOperators, denomination);

        // Assert
        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.MissingMembers(
            denomination,
            registry.minCommitteeMembers(),
            registry.minCommitteeMembers() - registry.minCommitteeOperators() - registry.minCommitteeWatchtowers()
        );

        // Act
        (CommitteeMember[] memory members, PendingCommitteeStatus status) = registry.selectCommittee(streamId);
        // Assert
        assertTrue(
            status == PendingCommitteeStatus.NOT_ENOUGH_MEMBERS,
            "Committee selection should fail due to not enough members"
        );
        assertEq(members.length, 0, "No members should be selected due to not enough members");
        assertTrue(
            registry.shouldCreateCommitteeHarness(streamId),
            "Should be able to create committee after not enough watchtowers"
        );
    }

    function test_getPendingCommittee_Revert_CommitteeIsNotPending() external {
        // Assert
        vm.expectRevert(abi.encodeWithSelector(ICommitteeRegistry.CommitteeIsNotPending.selector, 0));
        // Act
        registry.getPendingCommittee(0);
    }

    function test_createCommittee_Success_WithNewMembers() external {
        // This test should register all the members for a committee. This will trigger the creation of a pending committee.
        // We should complete that committee and then, with all the new members registered, we should be able to create a committee.
        // Arrange
        (, Committee memory expectedCommittee, uint64 streamId) = setup_completeCommitteeAndNewMembers();
        expectedCommittee.aggregatedKey = bytes32(0);

        // Assert
        assertFalse(
            registry.shouldCreateCommitteeHarness(streamId),
            "Flag should be false before createCommittee call from pegManager"
        );
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
        assertEq(missingData, registry.minCommitteeMembers(), "Missing data should be equal to minCommitteeMembers");
        assertFalse(
            registry.shouldCreateCommitteeHarness(streamId), "Should not create committee after committee created"
        );
        for (uint256 i = 0; i < committee.memberIndexesAndRoles.length; i++) {
            uint64 index = committee.memberIndexesAndRoles[i].index;
            assertTrue(
                index >= registry.minCommitteeMembers() && index < registry.minCommitteeMembers() * 2,
                "Member index should be within the second 10 members"
            );
        }
    }

    function test_createCommittee_Success_SameMembersAfterReApply() external {
        // After first committee is ready all the members apply again to the stream and create a new committee.
        // Arrange
        (, uint64 streamId) = setup_completeCommittee();

        assertEq(0, registry.getCommitteeCandidates(StreamDenomination(streamId), Role.OPERATOR).length);
        assertEq(0, registry.getCommitteeCandidates(StreamDenomination(streamId), Role.WATCHTOWER).length);

        uint256 numOperators = registry.minCommitteeMembers() / 2;
        uint256 numWatchtowers = registry.minCommitteeMembers() / 2;
        setup_applyToStream_MultipleMembers(StreamDenomination(streamId), numWatchtowers, numOperators, 0);
        Committee memory expectedCommittee = setup_getExpectedCommitteeBeforeExpire();
        expectedCommittee.aggregatedKey = bytes32(0);

        // Assert
        assertFalse(
            registry.shouldCreateCommitteeHarness(streamId),
            "Flag should be false before createCommittee call from pegManager"
        );
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
        assertEq(missingData, registry.minCommitteeMembers(), "Missing data should be equal to minCommitteeMembers");
        assertFalse(
            registry.shouldCreateCommitteeHarness(streamId), "Should not create committee after committee created"
        );
        for (uint256 i = 0; i < committee.memberIndexesAndRoles.length; i++) {
            uint64 index = committee.memberIndexesAndRoles[i].index;
            assertTrue(
                index >= 0 && index < registry.minCommitteeMembers(),
                "Member index should be within the first 10 members"
            );
        }
    }

    function test_createCommittee_Success_AlreadyPendingButNotExpired() external {
        // Arrange
        (, uint64 streamId) = setup_pendingCommittee();
        (Committee memory pendingCommittee, uint256 createdAt, uint256 missingData) =
            registry.getPendingCommittee(streamId);
        vm.recordLogs();

        // Assert
        assertFalse(
            registry.shouldCreateCommitteeHarness(streamId),
            "Flag should be false before createCommittee call from pegManager"
        );

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
        assertFalse(
            registry.shouldCreateCommitteeHarness(streamId), "Flag should be false after createCommittee call success"
        );
    }

    function test_getPendingCommittee_Success() external {
        // Arrange
        (Committee memory expectedCommittee, uint64 streamId) = setup_pendingCommittee();

        // Act
        (Committee memory committee, uint256 createdAt, uint256 missingData) = registry.getPendingCommittee(streamId);

        // Assert
        assertEqCommittee(committee, expectedCommittee, "get pending committee");
        assertNotEq(createdAt, 0);
        assertEq(missingData, registry.minCommitteeMembers());
    }

    function test_depositMemberInfoForCommittee_Success() external {
        // Arrange
        (Committee memory expectedCommittee, uint64 streamId) = setup_pendingCommittee();
        expectedCommittee.aggregatedKey = COMMITTEE_PUB_KEY;

        // Act
        vm.prank(vm.addr(1));
        registry.depositMemberInfoForCommittee(streamId, COMMITTEE_PUB_KEY);

        // Assert
        (Committee memory committee, uint256 createdAt, uint256 missingData) = registry.getPendingCommittee(streamId);
        assertEqCommittee(committee, expectedCommittee, "get pending committee");
        assertNotEq(createdAt, 0);
        assertEq(missingData, registry.minCommitteeMembers() - 1);
    }

    function test_depositMemberInfoForCommittee_Revert_InvalidAgregatedKey() external {
        // Arrange
        (, uint64 streamId) = setup_pendingCommittee();

        // Assert
        vm.expectRevert(abi.encodeWithSelector(ICommitteeRegistry.InvalidAgregatedKey.selector));

        // Act
        vm.prank(vm.addr(1));
        registry.depositMemberInfoForCommittee(streamId, bytes32(0));
    }

    function test_depositMemberInfoForCommittee_WrongCommitteeKey() external {
        // Arrange
        (Committee memory expectedCommittee, uint64 streamId) = setup_pendingCommittee();
        setup_depositMemberInfo(streamId, vm.addr(1));
        bytes32 wrongPubKey = 0x1908421cb37d204b0c68660d093534d50d01fa791a3313e5fd9c21da137785ec;

        // Assert
        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.NewPendingCommittee(streamId, expectedCommittee);

        // Act
        // Second member deposit wrong committee aggregated key, so discard current pending committee a create a new one.
        vm.prank(vm.addr(2));
        registry.depositMemberInfoForCommittee(streamId, wrongPubKey);

        // Assert
        (Committee memory committee, uint256 createdAt, uint256 missingData) = registry.getPendingCommittee(streamId);
        assertEqCommittee(committee, expectedCommittee, "get pending committee");
        assertNotEq(createdAt, 0);
        assertEq(missingData, registry.minCommitteeMembers());
    }

    function test_depositMemberInfoForCommittee_Success_CompleteCommittee() external {
        // Arrange
        (Committee memory expectedCommittee, uint64 streamId) = setup_pendingCommittee();
        expectedCommittee.aggregatedKey = COMMITTEE_PUB_KEY;
        uint256 memberIndexStart = 0;
        uint256 memberCount = registry.minCommitteeMembers() - 1;
        setup_depositMemberInfo_MultipleMembers(streamId, memberIndexStart, memberCount);

        // Assert
        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.NewCommittee(COMMITTEE_ID_STREAM_1_PACKET_0, expectedCommittee);

        // Act
        // Member address is vm.address(memberIndex + 1);
        vm.prank(vm.addr(registry.minCommitteeMembers()));
        registry.depositMemberInfoForCommittee(streamId, COMMITTEE_PUB_KEY);

        assertEq(
            registry.getCommitteeCandidates(StreamDenomination(streamId), Role.OPERATOR).length,
            0,
            "Should not have candidates after committee created"
        );
        assertEq(
            registry.getCommitteeCandidates(StreamDenomination(streamId), Role.WATCHTOWER).length,
            0,
            "Should not have candidates after committee created"
        );
    }

    function test_getPendingCommittee_Revert_CommitteeIsNotPending_AfterCompleteCommittee() external {
        // Arrange
        (, uint64 streamId) = setup_pendingCommittee();
        uint256 memberIndexStart = 0;
        uint256 memberCount = registry.minCommitteeMembers();
        setup_depositMemberInfo_MultipleMembers(streamId, memberIndexStart, memberCount);

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
        (Committee memory expectedCommittee, uint64 streamId) = setup_pendingCommittee();
        expectedCommittee.aggregatedKey = COMMITTEE_PUB_KEY;
        setup_depositMemberInfo(streamId, vm.addr(1));

        // Act
        bool isCommitteePendingExpired = registry.isPendingCommitteeExpired(streamId);

        // Assert
        // There is pending committee and it's not expired
        assertFalse(isCommitteePendingExpired, "pending committee is expired");
    }

    function test_isPendingCommitteeExpired_False_AfterSomeSeconds() external {
        // Arrange
        (Committee memory expectedCommittee, uint64 streamId) = setup_pendingCommittee();
        expectedCommittee.aggregatedKey = COMMITTEE_PUB_KEY;
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
        (, uint64 streamId) = setup_pendingCommittee();
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
        (, uint64 streamId) = setup_pendingCommittee();
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
        (Committee memory expectedCommittee, uint64 streamId) = setup_pendingCommitteeAndExpire();

        // Assert
        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.NewPendingCommittee(streamId, expectedCommittee);

        // Act
        vm.prank(address(pm));
        registry.createCommittee(streamId);

        // Assert
        (Committee memory committee, uint256 createdAt, uint256 missingData) = registry.getPendingCommittee(streamId);
        assertEqCommittee(committee, expectedCommittee, "get pending committee");
        assertNotEq(createdAt, 0);
        assertEq(missingData, registry.minCommitteeMembers());
    }

    function test_depositMemberInfoForCommittee_Success_CompleteCommitteeOnExpiredCommittee() external {
        // Having an expired committee does not prevent members to still deposit their data
        // Arrange
        (Committee memory expectedCommittee, uint64 streamId) = setup_pendingCommittee();
        uint256 timeout = registry.pendingCommitteeTimeout();
        vm.warp(block.timestamp + timeout + 1 seconds); // warp time to make committee expired
        expectedCommittee.aggregatedKey = COMMITTEE_PUB_KEY;
        uint256 memberIndexStart = 0;
        uint256 memberCount = registry.minCommitteeMembers() - 1;
        setup_depositMemberInfo_MultipleMembers(streamId, memberIndexStart, memberCount);

        // Assert
        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.NewCommittee(COMMITTEE_ID_STREAM_1_PACKET_0, expectedCommittee);

        // Act
        // Member address is vm.address(memberIndex + 1);
        vm.prank(vm.addr(registry.minCommitteeMembers()));
        registry.depositMemberInfoForCommittee(streamId, COMMITTEE_PUB_KEY);

        // Assert
        vm.expectRevert(abi.encodeWithSelector(ICommitteeRegistry.CommitteeIsNotPending.selector, streamId));
        // Act
        registry.getPendingCommittee(streamId);

        assertEq(
            registry.getCommitteeCandidates(StreamDenomination(streamId), Role.OPERATOR).length,
            0,
            "Should not have candidates after committee created"
        );
        assertEq(
            registry.getCommitteeCandidates(StreamDenomination(streamId), Role.WATCHTOWER).length,
            0,
            "Should not have candidates after committee created"
        );
    }

    function test_setPendingCommitteeTimeout_Success() external {
        // Arrange
        uint256 newTimeout = registry.pendingCommitteeTimeout() / 2;

        // Assert
        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.PendingCommitteeTimeoutUpdated(newTimeout);

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
        vm.expectRevert(abi.encodeWithSelector(ICommitteeRegistry.InvalidZeroValue.selector));

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

    function test_restartPendingCommittee_Revert_CommitteeIsNotPending() external {
        // Assert
        vm.expectRevert(abi.encodeWithSelector(ICommitteeRegistry.CommitteeIsNotPending.selector, 0));

        // Act
        registry.restartPendingCommittee(0);
    }

    function test_restartPendingCommittee_Revert_PendingCommitteeNotExpired() external {
        // Arrange
        (, uint64 streamId) = setup_pendingCommittee();
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
        (Committee memory expectedCommittee, uint64 streamId) = setup_pendingCommitteeAndExpire();

        // Assert
        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.NewPendingCommittee(streamId, expectedCommittee);

        // Act
        registry.restartPendingCommittee(streamId);

        // Assert
        (Committee memory committee, uint256 createdAt, uint256 missingData) = registry.getPendingCommittee(streamId);
        assertEqCommittee(committee, expectedCommittee, "get pending committee after restart");
        assertNotEq(createdAt, 0);
        assertEq(missingData, registry.minCommitteeMembers(), "missing data should be equal to min committee members");
        assertFalse(
            registry.shouldCreateCommitteeHarness(streamId), "Should not create committee after committee created"
        );
    }

    function test_setup_pendingCommitteeAndExpire() internal {
        // Test helper function to setup a pending committee and then expire it

        // Arrange
        // This function sets up a pending committee and then expires it
        (Committee memory expectedCommittee, uint64 streamId) = setup_pendingCommitteeAndExpire();
        // We ask for current pending committee
        (Committee memory currentPendingCommittee, uint256 createdAt,) = registry.getPendingCommittee(streamId);

        assertEq(
            expectedCommittee.memberIndexesAndRoles.length,
            currentPendingCommittee.memberIndexesAndRoles.length,
            "Pending committee length should match. They are always the MIN_MEMBERS_COMMITTEE"
        );
        for (uint256 i = 0; i < expectedCommittee.memberIndexesAndRoles.length; i++) {
            assertNotEq(
                expectedCommittee.memberIndexesAndRoles[i].index,
                currentPendingCommittee.memberIndexesAndRoles[i].index,
                "Pending committee member should not match"
            );
        }
        assertFalse(
            registry.shouldCreateCommitteeHarness(streamId),
            "Flag shouldCreateCommittee should be false before it's called by PegManager"
        );

        // Act
        vm.prank(address(pm));
        registry.createCommitteeHarness(streamId);

        (Committee memory pendingCommitteeAfterCall, uint256 createdAtAfterCall, uint256 missingDataAfterCall) =
            registry.getPendingCommittee(streamId);
        assertNotEq(createdAt, createdAtAfterCall, "Pending committee should change");
        assertEq(0, missingDataAfterCall, "Missing data should be 0 after committee creation");
        assertEq(
            bytes32(0),
            pendingCommitteeAfterCall.aggregatedKey,
            "Pending committee aggregated key should be empty after committee creation"
        );
        assertEqCommittee(
            expectedCommittee,
            pendingCommitteeAfterCall,
            "New pending committee should match that one returned by setup_pendingCommitteeAndExpire"
        );
        assertFalse(
            registry.shouldCreateCommitteeHarness(streamId), "Should not create committee after committee created"
        );
    }

    function test_createCommitteeAfterApplyToStream_Success_NotExpiredPendingCommittee() external {
        // Arrange
        (Committee memory expectedCommittee, uint64 streamId) = setup_pendingCommittee();
        StreamDenomination denomination = StreamDenomination(streamId);
        (, uint256 createdAt, uint256 missingData) = registry.getPendingCommittee(streamId);
        vm.recordLogs();

        // createCommitteeAfterApplyToStream called should do nothing if pending committee is not expired
        // Act
        registry.createCommitteeAfterApplyToStreamHarness(denomination);

        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertEq(logs.length, 0, "Expected no events to be emitted");

        (Committee memory pendingCommitteeAfterCall, uint256 createdAtAfterCall, uint256 missingDataAfterCall) =
            registry.getPendingCommittee(streamId);
        assertEq(createdAtAfterCall, createdAt, "Pending committee should not change");
        assertEq(missingDataAfterCall, missingData, "Pending committee should not change");
        assertEq(
            pendingCommitteeAfterCall.aggregatedKey,
            expectedCommittee.aggregatedKey,
            "Pending committee should not change"
        );
        assertEqCommitteeMembers(
            pendingCommitteeAfterCall.memberIndexesAndRoles,
            expectedCommittee.memberIndexesAndRoles,
            "Create committee should not change members"
        );
    }

    function test_createCommitteeAfterApplyToStream_Success_ExpiredPendingCommittee() external {
        // Arrange
        (Committee memory expectedCommittee, uint64 streamId) = setup_pendingCommitteeAndExpire();
        StreamDenomination denomination = StreamDenomination(streamId);
        (, uint256 createdAt,) = registry.getPendingCommittee(streamId);

        // Assert
        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.NewPendingCommittee(streamId, expectedCommittee);

        // createCommitteeAfterApplyToStream called should create a new pending committee if the previous one is expired
        // Act
        registry.createCommitteeAfterApplyToStreamHarness(denomination);

        (Committee memory pendingCommitteeAfterCall, uint256 createdAtAfterCall, uint256 missingDataAfterCall) =
            registry.getPendingCommittee(streamId);
        assertEq(
            missingDataAfterCall, expectedCommittee.memberIndexesAndRoles.length, "Pending committee should not change"
        );
        assertNotEq(createdAt, createdAtAfterCall, "Pending committee should change");
        assertEq(
            pendingCommitteeAfterCall.aggregatedKey,
            expectedCommittee.aggregatedKey,
            "Pending committee should not change"
        );
        assertEqCommitteeMembers(
            pendingCommitteeAfterCall.memberIndexesAndRoles,
            expectedCommittee.memberIndexesAndRoles,
            "Create committee should not change members"
        );
    }

    function test_createCommitteeAfterApplyToStream_Success_NoCommitteeForCurrentPacket() external {
        // In this case we want to test the case where we run out of slots from current packet without being ables to create a new pending committee.
        // This is a edge case where we had the minimum of members to create first packet but one of the members decided to unsubscribe from the stream for next packet
        // So pending committee wont be created in each of the last pegins of current packet. Resulting in no pending committee for next packet.
        // applyToStream call internally to `createCommitteeAfterApplyToStream`

        // ===== Arrange start =====
        // Create a complete committee for initial packet
        (,, uint64 streamId) = setup_completeCommitteeAndNewMembers();
        StreamDenomination denomination = StreamDenomination(streamId);
        // Need to use last member in the committee to unsubscribe and subscribe to keep same random committee member order
        uint256 userIndex = registry.minCommitteeMembers() * 2 - 1;
        Role userRole = Role.OPERATOR;
        address userAddress = vm.addr(userIndex + 1);
        PublicKeyRegistration[] memory pubKeysRegistration = generatePublicKeysRegistration(userIndex + 1);

        // Unsubscribe one of the members
        vm.prank(userAddress);
        registry.unsubscribeFromStream(denomination);

        // Use all the slots in the packet
        setup_multipleRequestAndAcceptPeginFlows(Constants.SLOTS_PER_PACKET, streamId);

        Stream memory stream = streamManager.getStreamById(streamId);
        assertEq(stream.peginPacketPointer, 1, "Stream pegin packet pointer should be 1 after filling all slots");

        // Check that current packet does not have a committee
        uint256 currentPacketCommitteeId = streamManager.getCurrentPacketCommitteeId(streamId);
        assertEq(currentPacketCommitteeId, 0, "Current packet committee ID should be 0 when no committee exists");

        // Check there is no pending committee
        vm.expectRevert(abi.encodeWithSelector(ICommitteeRegistry.CommitteeIsNotPending.selector, streamId));
        registry.getPendingCommittee(streamId);

        uint256 minimumDeposit = registry.getMinimumDeposit(denomination);
        vm.deal(userAddress, minimumDeposit);
        Committee memory expectedCommittee = setup_getExpectedSecondCommittee();
        vm.warp(BLOCK_TIMESTAMP_FOR_DETERMINISTIC_COMMITTEE);
        assertTrue(
            registry.shouldCreateCommitteeHarness(streamId),
            "Flag should be true because there is no pending committee and need one to new packet"
        );
        // ===== Arrange end =====

        // Assert
        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.NewPendingCommittee(streamId, expectedCommittee);

        // Act
        vm.prank(userAddress);
        registry.applyToStream{value: minimumDeposit}(denomination, userRole, pubKeysRegistration);

        // Assert
        (Committee memory pendingCommittee, uint256 createdAt, uint256 missingData) =
            registry.getPendingCommittee(streamId);
        assertEqCommittee(pendingCommittee, expectedCommittee, "get pending committee after apply to stream");
        assertNotEq(createdAt, 0, "Created at should not be 0 after apply to stream");
        assertEq(missingData, registry.minCommitteeMembers(), "Missing data should be equal to min committee members");
        assertFalse(registry.shouldCreateCommitteeHarness(streamId), "Flag should be false before createCommittee call");
    }
}
