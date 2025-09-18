// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {
    ICommitteeRegistry,
    PendingCommitteeStatus,
    Role,
    CommitteeMember,
    Committee,
    CommunicationData,
    COMMUNICATION_DATA_CHUNKS,
    MemberRegistrationKeys
} from "src/interfaces/ICommitteeRegistry.sol";
import {IMemberRegistry} from "src/interfaces/IMemberRegistry.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {StreamDenomination, IStreamManager, Stream} from "src/interfaces/IStreamManager.sol";
import {
    HelperContract,
    StreamManagerHarness,
    PegManagerHarness,
    MemberRegistryHarness
} from "test/helpers/HelperContract.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Constants} from "src/libraries/Constants.sol";

contract TestCommitteeRegistry is Test, HelperContract {
    uint256 constant MAX_GAS_PER_COMMITTEE_CREATION = 1500 * 1000; // Max gas per block in RSK is 6M8

    function setUp() external {
        runTestDeployScript();
        vm.roll(1000);
    }

    function pauseRegistry() internal {
        address pauser = registry.pauser();
        vm.prank(pauser);
        registry.pause();
    }

    function pauseAndUnpauseRegistry() internal {
        address pauser = registry.pauser();
        vm.startPrank(pauser);
        registry.pause();
        registry.unpause();
        vm.stopPrank();
    }

    function test_Success_PauserIsPegManager() external view {
        assertEq(registry.pauser(), address(pm));
    }

    function test_pause_Revert_UnauthorizedAccount_CallFromNotPauser() external {
        // Assert
        vm.expectRevert(abi.encodeWithSelector(ICommitteeRegistry.UnauthorizedAccount.selector, address(this)));

        // Act
        registry.pause();
    }

    function test_pause_Success_CallFromPauser() external {
        // Arrange
        address pauser = registry.pauser();

        // Assert
        vm.expectEmit(address(registry));
        emit PausableUpgradeable.Paused(pauser);

        // Act
        vm.prank(pauser);
        registry.pause();
    }

    function test_unpause_Revert_UnauthorizedAccount_CallFromNotPauser() external {
        // Arrange
        pauseRegistry();

        // Assert
        vm.expectRevert(abi.encodeWithSelector(ICommitteeRegistry.UnauthorizedAccount.selector, address(this)));

        // Act
        registry.unpause();
    }

    function test_unpause_Success_CallFromPauser() external {
        // Arrange
        pauseRegistry();
        address pauser = registry.pauser();

        // Assert
        vm.expectEmit(address(registry));
        emit PausableUpgradeable.Unpaused(pauser);

        // Act
        vm.prank(pauser);
        registry.unpause();
    }

    function test_unpause_Revert_ExpectedPause_CallFromPauser_ContractNotPaused() external {
        // Arrange
        address pauser = registry.pauser();

        // Assert
        vm.expectRevert(abi.encodeWithSelector(PausableUpgradeable.ExpectedPause.selector, address(this)));

        // Act
        vm.prank(pauser);
        registry.unpause();
    }

    function test_pause_Revert_EnforcedPause_CallFromPauser_ContractAlreadyPaused() external {
        // Arrange
        pauseRegistry();
        address pauser = registry.pauser();

        // Assert
        vm.expectRevert(abi.encodeWithSelector(PausableUpgradeable.EnforcedPause.selector, address(this)));

        // Act
        vm.prank(pauser);
        registry.pause();
    }

    function test_pause_CallFromPauser_ShouldAlsoPauseMemberRegistry() external {
        // Arrange
        address pauser = registry.pauser();
        address registryAddress = address(registry);
        address memberRegistryAddress = address(memberRegistry);

        // Assert
        vm.expectEmit(memberRegistryAddress);
        emit PausableUpgradeable.Paused(registryAddress);

        // Act
        vm.prank(pauser);
        registry.pause();
    }

    function test_applyToStream_Revert_EnforcedPause_PausedContract() external {
        // Arrange
        pauseRegistry();

        uint256 privKey = uint256(1);
        address member = vm.addr(privKey);
        MemberRegistrationKeys memory memberRegistrationKeys = generateRegistrationPublicKeys(privKey);

        StreamDenomination denomination = StreamDenomination._0_01BTC;
        Role role = Role.OPERATOR;
        uint256 minimumDeposit = streamManager.getMinimumDeposit(denomination, role);
        vm.deal(member, minimumDeposit);

        // Assert
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);

        // Act
        vm.prank(member);
        registry.applyToStream{value: minimumDeposit}(denomination, role, memberRegistrationKeys, generateDefaultUTXO());
    }

    function test_applyToStream_Success_UnpausedContract() external {
        // Arrange
        pauseAndUnpauseRegistry();

        uint256 privKey = uint256(1);
        address member = vm.addr(privKey);
        MemberRegistrationKeys memory memberRegistrationKeys = generateRegistrationPublicKeys(privKey);
        StreamDenomination denomination = StreamDenomination._0_01BTC;
        Role role = Role.OPERATOR;

        // Act
        setup_applyToStream(denomination, member, memberRegistrationKeys, role);

        // Assert
        memberRegistry.getMemberPublicKeys(member);
    }

    function test_unsubscribeFromStream_Revert_EnforcedPause_PausedContract() external {
        // Arrange
        // member should have applied to the stream before unsubscribing from it
        uint256 privKey = uint256(1);
        address member = vm.addr(privKey);
        MemberRegistrationKeys memory memberRegistrationKeys = generateRegistrationPublicKeys(privKey);
        StreamDenomination denomination = StreamDenomination._0_01BTC;
        Role role = Role.OPERATOR;
        setup_applyToStream(denomination, member, memberRegistrationKeys, role);

        pauseRegistry();

        // Assert
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);

        // Act
        vm.prank(member);
        registry.unsubscribeFromStream(denomination);
    }

    function test_unsubscribeFromStream_Success_UnpausedContract() external {
        // Arrange
        // member should have applied to the stream before unsubscribing from it
        uint256 privKey = uint256(1);
        address member = vm.addr(privKey);
        MemberRegistrationKeys memory memberRegistrationKeys = generateRegistrationPublicKeys(privKey);
        StreamDenomination denomination = StreamDenomination._0_01BTC;
        Role role = Role.OPERATOR;
        setup_applyToStream(denomination, member, memberRegistrationKeys, role);

        pauseAndUnpauseRegistry();

        // Assert
        vm.expectEmit(address(memberRegistry));
        emit IMemberRegistry.MemberUnsubscribedFromStream(member, denomination);

        // Act
        vm.prank(member);
        registry.unsubscribeFromStream(denomination);
    }

    function test_restartPendingCommittee_Revert_EnforcedPause_PausedContract() external {
        // Arrange
        (Committee memory expectedCommittee,) = setup_pendingCommitteeAndExpire();

        pauseRegistry();

        // Assert
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);

        // Act
        registry.restartPendingCommittee(expectedCommittee.streamId);
    }

    function test_restartPendingCommittee_Success_UnpausedContract() external {
        // Arrange
        pauseAndUnpauseRegistry();

        (Committee memory expectedCommittee,) = setup_pendingCommitteeAndExpire();

        // Assert
        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.NewPendingCommittee(COMMITTEE_ID_STREAM_1_COMMITTEE_3, expectedCommittee);

        // Act
        registry.restartPendingCommittee(expectedCommittee.streamId);
    }

    function test_createCommittee_Success_PausedContract() external {
        // Arrange
        (, Committee memory expectedCommittee, uint128 committeeId) = setup_completeCommitteeAndNewMembers();
        expectedCommittee.aggregatedKey = new bytes(0);

        pauseRegistry();

        // Assert
        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.NewPendingCommittee(committeeId, expectedCommittee);

        // Act
        // This should create a committee as pending
        vm.prank(address(pm));
        registry.createCommittee(expectedCommittee.streamId);
    }

    function test_depositAggregatedKey_Revert_EnforcedPause_PausedContract() external {
        // Arrange
        (Committee memory expectedCommittee, uint128 committeeId) = setup_pendingCommittee();
        bytes memory aggregatedKey = COMMITTEE_PUB_KEY();
        expectedCommittee.aggregatedKey = aggregatedKey;
        CommitteeMember memory member = registry.getCommitteeMembers(committeeId)[0];
        address memberAddress = member.memberAddress;

        pauseRegistry();

        // Assert
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);

        // Act
        vm.prank(memberAddress);
        registry.depositAggregatedKey(committeeId, aggregatedKey);
    }

    function test_depositAggregatedKey_Success_UnpausedContract() external {
        // Arrange
        pauseAndUnpauseRegistry();

        (Committee memory expectedCommittee, uint128 committeeId) = setup_pendingCommittee();
        bytes memory aggregatedKey = COMMITTEE_PUB_KEY();
        expectedCommittee.aggregatedKey = aggregatedKey;

        CommitteeMember memory member = registry.getCommitteeMembers(committeeId)[0];
        address memberAddress = member.memberAddress;

        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.MemberInfoDeposited(committeeId, memberAddress, aggregatedKey);

        // Act
        vm.prank(memberAddress);
        registry.depositAggregatedKey(committeeId, aggregatedKey);
    }

    function test_depositCommunicationData_Revert_EnforcedPause_PausedContract() external {
        // Arrange
        pauseRegistry();

        uint256 privKey = uint256(2);
        address member = vm.addr(privKey);

        uint256 expectedCommitteeSize = 1;
        uint256 memberIndex = 0;
        CommunicationData[] memory communicationData = createValidCommunicationData(expectedCommitteeSize, memberIndex);

        // Assert
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);

        // Act
        vm.prank(member);
        registry.depositCommunicationData(0, communicationData);
    }

    function test_depositCommunicationData_Success_UnpausedContract() external {
        // Arrange
        pauseAndUnpauseRegistry();

        (Committee memory expectedCommittee, uint128 committeeId) = setup_pendingCommittee();
        uint256 memberIndex = 0;
        address memberAddress = expectedCommittee.members[memberIndex].memberAddress;

        CommunicationData[] memory communicationData =
            createValidCommunicationData(expectedCommittee.members.length, memberIndex);

        // Assert
        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.MemberCommunicationDataDeposited(committeeId, memberAddress, communicationData);

        // Act
        vm.prank(memberAddress);
        registry.depositCommunicationData(committeeId, communicationData);
    }

    function test_setStreamManager_Success_PausedContract() external {
        // Arrange
        pauseRegistry();

        uint256 privKey = uint256(2);
        address newStreamManagerAddress = vm.addr(privKey);
        StreamManagerHarness newStreamManager = StreamManagerHarness(newStreamManagerAddress);
        address owner = registry.owner();

        // Assert
        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.StreamManagerUpdated(newStreamManagerAddress);

        // Act
        vm.prank(owner);
        registry.setStreamManager(newStreamManager);
    }

    function test_setPegManager_Success_PausedContract() external {
        // Arrange
        pauseRegistry();

        uint256 privKey = uint256(2);
        address newPegManagerAddress = vm.addr(privKey);
        PegManagerHarness newPegManager = PegManagerHarness(newPegManagerAddress);
        address owner = registry.owner();

        // Assert
        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.PegManagerUpdated(newPegManagerAddress);

        // Act
        vm.prank(owner);
        registry.setPegManager(newPegManager);
    }

    function test_setMemberRegistry_Success_PausedContract() external {
        // Arrange
        pauseRegistry();

        uint256 privKey = uint256(2);
        address newMemberAddress = vm.addr(privKey);
        MemberRegistryHarness newMemberRegistry = MemberRegistryHarness(newMemberAddress);
        address owner = registry.owner();

        // Assert
        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.MemberRegistryUpdated(newMemberAddress);

        // Act
        vm.prank(owner);
        registry.setMemberRegistry(newMemberRegistry);
    }

    function test_setPendingCommitteeTimeout_Success_PausedContract() external {
        // Arrange
        pauseRegistry();

        uint256 newCommitteeTimeout = uint256(5);
        address owner = registry.owner();

        // Assert
        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.PendingCommitteeTimeoutUpdated(newCommitteeTimeout);

        // Act
        vm.prank(owner);
        registry.setPendingCommitteeTimeout(newCommitteeTimeout);
    }

    function test_setCommitteeMinWatchtowers_Success_PausedContract() external {
        // Arrange
        pauseRegistry();

        uint256 newMinWatchtowers = registry.committeeMemberCount() - registry.minCommitteeOperators(); // to be sure committeeMemberCount >= newMin + minCommitteeOperators
        address owner = registry.owner();

        // Assert
        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.CommitteeMinWatchtowersUpdated(newMinWatchtowers);

        // Act
        vm.prank(owner);
        registry.setCommitteeMinWatchtowers(newMinWatchtowers);
    }

    function test_setCommitteeMinOperators_Success_PausedContract() external {
        // Arrange
        pauseRegistry();

        uint256 newMinOperators = registry.committeeMemberCount() - registry.minCommitteeWatchtowers(); // to be sure committeeMemberCount >= minCommitteeWatchtowers + newMin
        address owner = registry.owner();

        // Assert
        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.CommitteeMinOperatorsUpdated(newMinOperators);

        // Act
        vm.prank(owner);
        registry.setCommitteeMinOperators(newMinOperators);
    }

    function test_setCommitteeMemberCount_Success_PausedContract() external {
        // Arrange
        pauseRegistry();

        uint256 memberCount = registry.minCommitteeWatchtowers() + registry.minCommitteeOperators(); // to be sure memberCount >= minCommitteeWatchtowers + minCommitteeOperators
        address owner = registry.owner();

        // Assert
        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.CommitteeMemberCountUpdated(memberCount);

        // Act
        vm.prank(owner);
        registry.setCommitteeMemberCount(memberCount);
    }

    function test_releaseCommittee_Success_PausedContract() external {
        // Arrange
        // create committee to be released
        setup_pendingCommittee();
        uint128 committeeId = COMMITTEE_ID_STREAM_1_COMMITTEE_1;
        bytes memory committeePubKey = new bytes(1);

        uint64 streamId = uint64(SETUP_PENDING_COMMITTEE_DENOMINATION);
        uint64 packetNumber = 0;
        vm.prank(address(registry));
        streamManager.createNewPacket(streamId, committeeId, committeePubKey);

        pauseRegistry();

        // Assert
        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.CommitteeMembersReleased(streamId, packetNumber);

        // Act
        vm.prank(address(pm));
        registry.releaseCommittee(streamId, packetNumber);
    }

    function test_shouldCreateCommittee_AfterInit() external view {
        for (uint64 i = 0; i < uint64(StreamDenomination.LENGTH); i++) {
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

    function test_setCommitteeMinWatchtowers_Revert_InvalidMinWatchtowers() external {
        address owner = registry.owner();
        uint256 minMembers = registry.committeeMemberCount();
        uint256 minOperators = registry.minCommitteeOperators();
        uint256 invalidMinWatchtowers = minMembers - minOperators + 1;

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                ICommitteeRegistry.InvalidMinWatchtowers.selector, minMembers, invalidMinWatchtowers, minOperators
            )
        );

        // Act
        vm.prank(address(owner));
        registry.setCommitteeMinWatchtowers(invalidMinWatchtowers);
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

    function test_setCommitteeMinOperators_Revert_InvalidMinOperators() external {
        address owner = registry.owner();
        uint256 minMembers = registry.committeeMemberCount();
        uint256 minWatchtowers = registry.minCommitteeWatchtowers();
        uint256 invalidMinOperators = minMembers - minWatchtowers + 1;

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                ICommitteeRegistry.InvalidMinOperators.selector, minMembers, minWatchtowers, invalidMinOperators
            )
        );

        // Act
        vm.prank(address(owner));
        registry.setCommitteeMinOperators(invalidMinOperators);
    }

    function test_setCommitteeMemberCount_Success() external {
        // Arrange
        uint256 newMinMembers = registry.committeeMemberCount() + 1;

        // Assert
        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.CommitteeMemberCountUpdated(newMinMembers);

        // Act
        vm.prank(address(registry.owner()));
        registry.setCommitteeMemberCount(newMinMembers);

        // Assert
        assertEq(registry.committeeMemberCount(), newMinMembers, "Committee min members should be updated");
    }

    function test_setCommitteeMemberCount_Revert_OwnableUnauthorizedAccount() external {
        // Arrange
        uint256 newMinMembers = registry.committeeMemberCount() + 1;

        // Assert
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));

        // Act
        registry.setCommitteeMemberCount(newMinMembers);
    }

    function test_setCommitteeMemberCount_Revert_InvalidZeroValue() external {
        address owner = registry.owner();

        // Assert
        vm.expectRevert(abi.encodeWithSelector(ICommitteeRegistry.InvalidZeroValue.selector));

        // Act
        vm.prank(address(owner));
        registry.setCommitteeMemberCount(0);
    }

    function test_setCommitteeMemberCount_Revert_InvalidMinMembers() external {
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
        registry.setCommitteeMemberCount(invalidMinMembers);
    }

    function test_getCommittee_Success() external {
        // Arrange
        (Committee memory expectedCommittee, uint128 committeeId) = setup_completeCommittee();

        // Act
        Committee memory committee = registry.getCommittee(committeeId);
        // Assert
        assertEqCommittee(expectedCommittee, committee, "Committees are not equal");
        assertFalse(
            registry.shouldCreateCommitteeHarness(expectedCommittee.streamId),
            "shouldCreateCommittee should be false after setup completeCommittee call"
        );

        for (uint64 i = 0; i < uint64(StreamDenomination.LENGTH); i++) {
            if (i != expectedCommittee.streamId) {
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
        CommitteeMember[] memory members = registry.getCommitteeMembers(COMMITTEE_ID_STREAM_1_COMMITTEE_1);
        // Assert
        assertEqCommitteeMembers(expectedCommittee.members, members, "Member list are not equal");
    }

    function test_selectCommittee_Success_MinOperators() external {
        // Arrange
        StreamDenomination denomination = StreamDenomination._0_01BTC;
        uint64 streamId = 1;
        uint256 numOperators = registry.minCommitteeOperators();
        uint256 numWatchtowers = registry.committeeMemberCount() - numOperators;
        setup_registerNewMembers(numWatchtowers, numOperators, denomination);

        // Act
        (CommitteeMember[] memory selectedMembers, PendingCommitteeStatus status) = registry.selectCommittee(streamId);

        // Assert - Verify status and committee has correct size
        assertTrue(status == PendingCommitteeStatus.SUCCESS, "Committee selection should be successful");
        assertEq(selectedMembers.length, registry.committeeMemberCount(), "Committee should have 10 members");

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
            registry.committeeMemberCount() - registry.minCommitteeOperators(),
            "Committee should have 7 watchtowers"
        );
        assertEq(operatorCount, registry.minCommitteeOperators(), "Committee should have 7 operators");

        assertUniqueMembers(selectedMembers);
    }

    function assertUniqueMembers(CommitteeMember[] memory selectedMembers) internal pure {
        for (uint256 i = 0; i < selectedMembers.length; i++) {
            for (uint256 j = i + 1; j < selectedMembers.length; j++) {
                assertNotEq(
                    selectedMembers[i].memberAddress,
                    selectedMembers[j].memberAddress,
                    "There is a repeated member in selected members"
                );
            }
        }
    }

    function test_selectCommittee_Success_MinWatchtowers() external {
        // Arrange
        StreamDenomination denomination = StreamDenomination._0_01BTC;
        uint64 streamId = 1;
        uint256 numWatchtowers = registry.minCommitteeWatchtowers();
        uint256 numOperators = registry.committeeMemberCount() - numWatchtowers;
        setup_registerNewMembers(numWatchtowers, numOperators, denomination);

        // Act
        (CommitteeMember[] memory selectedMembers, PendingCommitteeStatus status) = registry.selectCommittee(streamId);

        // Assert - Verify status and committee has correct size
        assertTrue(status == PendingCommitteeStatus.SUCCESS, "Committee selection should be successful");
        assertEq(selectedMembers.length, registry.committeeMemberCount(), "Committee should have 10 members");

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
            registry.committeeMemberCount() - registry.minCommitteeWatchtowers(),
            "Committee should have 7 operators"
        );

        assertUniqueMembers(selectedMembers);
    }

    function test_selectCommittee_ReturnsDifferentCommittees() external {
        // Arrange
        StreamDenomination denomination = StreamDenomination._0_01BTC;
        uint64 streamId = 1;
        uint256 numWachtowers = registry.minCommitteeWatchtowers();
        uint256 numOperators = registry.committeeMemberCount();
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
        assertEq(selectedMembers1.length, registry.committeeMemberCount(), "First committee should have 10 members");
        assertEq(selectedMembers2.length, registry.committeeMemberCount(), "Second committee should have 10 members");

        // Verify selections are different (at least one member is in a different position)
        bool isDifferent = false;
        for (uint256 i = 0; i < selectedMembers1.length; i++) {
            if (selectedMembers1[i].memberAddress != selectedMembers2[i].memberAddress) {
                isDifferent = true;
                break;
            }
        }
        assertTrue(isDifferent, "Selections should be different with different timestamps");
    }

    function test_selectCommittee_Emit_MissingWatchtowers() external {
        // Arrange
        StreamDenomination denomination = StreamDenomination._0_01BTC;
        uint64 streamId = 1;
        uint256 numWatchtowers = registry.minCommitteeWatchtowers() - 1;
        uint256 numOperators = registry.committeeMemberCount() - numWatchtowers + 1;
        setup_registerNewMembers(numWatchtowers, numOperators, denomination);

        // Assert that selectCommittee emits MissingWatchtowers event
        vm.expectEmit(address(memberRegistry));
        emit IMemberRegistry.MissingWatchtowers(denomination, registry.minCommitteeWatchtowers(), 1);

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

    function test_selectCommittee_Emit_MissingOperators() external {
        // Arrange
        StreamDenomination denomination = StreamDenomination._0_01BTC;
        uint64 streamId = 1;
        uint256 numOperators = registry.minCommitteeOperators() - 1;
        uint256 numWatchtowers = registry.committeeMemberCount() - numOperators + 1;
        setup_registerNewMembers(numWatchtowers, numOperators, denomination);

        // Assert that selectCommittee emits MissingOperators event
        vm.expectEmit(address(memberRegistry));
        emit IMemberRegistry.MissingOperators(denomination, registry.minCommitteeOperators(), 1);

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

    function test_selectCommittee_Emit_MissingMembers() external {
        // Arrange
        StreamDenomination denomination = StreamDenomination._0_01BTC;
        uint64 streamId = 1;
        uint256 numOperators = registry.minCommitteeOperators();
        uint256 numWatchtowers = registry.minCommitteeWatchtowers();
        setup_registerNewMembers(numWatchtowers, numOperators, denomination);

        // Assert
        vm.expectEmit(address(memberRegistry));
        emit IMemberRegistry.MissingMembers(
            denomination,
            registry.committeeMemberCount(),
            registry.committeeMemberCount() - registry.minCommitteeOperators() - registry.minCommitteeWatchtowers()
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
        (, Committee memory expectedCommittee, uint128 committeeId) = setup_completeCommitteeAndNewMembers();
        expectedCommittee.aggregatedKey = new bytes(0);

        // Assert
        assertFalse(
            registry.shouldCreateCommitteeHarness(expectedCommittee.streamId),
            "Flag should be false before createCommittee call from pegManager"
        );
        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.NewPendingCommittee(committeeId, expectedCommittee);

        // Act
        // This should create a committee as pending
        vm.prank(address(pm));
        registry.createCommittee(expectedCommittee.streamId);

        Committee memory committee = registry.getPendingCommittee(expectedCommittee.streamId);
        // Assert
        assertEqCommittee(expectedCommittee, committee, "Committee should be equeals");
        assertNotEq(committee.createdAt, 0, "Created at should not be 0");
        assertEq(
            committee.missingData,
            registry.committeeMemberCount(),
            "Missing data should be equal to committeeMemberCount"
        );
        assertFalse(
            registry.shouldCreateCommitteeHarness(expectedCommittee.streamId),
            "Should not create committee after committee created"
        );
    }

    function test_createCommittee_Success_SameMembersAfterReApply() external {
        // After first committee is ready all the members apply again to the stream and create a new committee.
        // Arrange
        (Committee memory committee,) = setup_completeCommittee();
        StreamDenomination denomination = StreamDenomination(committee.streamId);

        assertEq(0, memberRegistry.getCommitteeCandidates(denomination, Role.OPERATOR).length);
        assertEq(0, memberRegistry.getCommitteeCandidates(denomination, Role.WATCHTOWER).length);

        uint256 numOperators = registry.committeeMemberCount() / 2;
        uint256 numWatchtowers = registry.committeeMemberCount() / 2;
        vm.warp(BLOCK_COMMITTEE_3);
        vm.roll(BLOCK_COMMITTEE_3);
        setup_applyToStream_MultipleMembers(denomination, numWatchtowers, numOperators, 0);

        Committee memory expectedCommittee = setup_getExpectedCommitteeAfterExpire();
        expectedCommittee.aggregatedKey = new bytes(0);

        // Assert
        assertFalse(
            registry.shouldCreateCommitteeHarness(committee.streamId),
            "Flag should be false before createCommittee call from pegManager"
        );
        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.NewPendingCommittee(COMMITTEE_ID_STREAM_1_COMMITTEE_3, expectedCommittee);

        // Act
        // This should create a committee as pending
        vm.prank(address(pm));
        registry.createCommittee(committee.streamId);

        Committee memory pendingCommittee = registry.getPendingCommittee(committee.streamId);
        // Assert
        assertEqCommittee(expectedCommittee, pendingCommittee, "Committee should be equeals");
        assertNotEq(committee.createdAt, 0, "Created at should not be 0");
        assertEq(
            pendingCommittee.missingData,
            registry.committeeMemberCount(),
            "Missing data should be equal to committeeMemberCount"
        );
        assertFalse(
            registry.shouldCreateCommitteeHarness(committee.streamId),
            "Should not create committee after committee created"
        );
    }

    function test_createCommittee_Success_AlreadyPendingButNotExpired() external {
        // Arrange
        (Committee memory expectedCommittee,) = setup_pendingCommittee();
        Committee memory pendingCommittee = registry.getPendingCommittee(expectedCommittee.streamId);
        vm.recordLogs();

        // Assert
        assertFalse(
            registry.shouldCreateCommitteeHarness(expectedCommittee.streamId),
            "Flag should be false before createCommittee call from pegManager"
        );

        // createCommittee called by pegManager should do nothing if pending committee is not expired
        // Act
        vm.prank(address(pm));
        registry.createCommittee(expectedCommittee.streamId);

        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertEq(logs.length, 0, "Expected no events to be emitted");

        Committee memory pendingCommitteeAfterCall = registry.getPendingCommittee(expectedCommittee.streamId);

        assertEq(pendingCommittee.createdAt, pendingCommitteeAfterCall.createdAt, "Pending committee should not change");
        assertEq(
            pendingCommittee.missingData, pendingCommitteeAfterCall.missingData, "Pending committee should not change"
        );
        assertEq(
            pendingCommittee.aggregatedKey,
            pendingCommitteeAfterCall.aggregatedKey,
            "Pending committee should not change"
        );
        assertEqCommitteeMembers(
            pendingCommittee.members, pendingCommitteeAfterCall.members, "Create committee should not change members"
        );
        assertFalse(
            registry.shouldCreateCommitteeHarness(expectedCommittee.streamId),
            "Flag should be false after createCommittee call success"
        );
    }

    function test_getPendingCommittee_Success() external {
        // Arrange
        (Committee memory expectedCommittee,) = setup_pendingCommittee();

        // Act
        Committee memory committee = registry.getPendingCommittee(expectedCommittee.streamId);

        // Assert
        assertEqCommittee(committee, expectedCommittee, "get pending committee");
        assertNotEq(committee.createdAt, 0);
        assertEq(committee.missingData, registry.committeeMemberCount());
    }

    function test_depositAggregatedKey_Success() external {
        // Arrange
        (Committee memory expectedCommittee, uint128 committeeId) = setup_pendingCommittee();
        expectedCommittee.aggregatedKey = COMMITTEE_PUB_KEY();

        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.MemberInfoDeposited(committeeId, vm.addr(1), COMMITTEE_PUB_KEY());

        // Act
        vm.prank(vm.addr(1));
        registry.depositAggregatedKey(committeeId, COMMITTEE_PUB_KEY());

        // Assert
        Committee memory committee = registry.getPendingCommittee(expectedCommittee.streamId);
        assertEqCommittee(committee, expectedCommittee, "get pending committee");
        assertNotEq(committee.createdAt, 0);
        assertEq(committee.missingData, registry.committeeMemberCount() - 1);
    }

    function test_depositAggregatedKey_Revert_MemberInfoAlreadyDeposited() external {
        // Arrange
        (Committee memory expectedCommittee, uint128 committeeId) = setup_pendingCommittee();
        expectedCommittee.aggregatedKey = COMMITTEE_PUB_KEY();
        address memberAddress = vm.addr(1);
        // Deposit data for the first time
        vm.prank(memberAddress);
        registry.depositAggregatedKey(committeeId, COMMITTEE_PUB_KEY());

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(ICommitteeRegistry.MemberInfoAlreadyDeposited.selector, committeeId, memberAddress)
        );

        // Act
        vm.prank(memberAddress);
        registry.depositAggregatedKey(committeeId, COMMITTEE_PUB_KEY());
    }

    function test_depositAggregatedKey_Revert_MemberNotInCommittee() external {
        // Arrange
        (Committee memory expectedCommittee, uint128 committeeId) = setup_pendingCommittee();
        expectedCommittee.aggregatedKey = COMMITTEE_PUB_KEY();
        address notCommitteeMember = vm.addr(registry.committeeMemberCount() + 1);
        MemberRegistrationKeys memory publicKeysRegistration =
            generateRegistrationPublicKeys(uint256(uint160(notCommitteeMember)));
        setup_applyToStream(
            StreamDenomination(expectedCommittee.streamId), notCommitteeMember, publicKeysRegistration, Role.OPERATOR
        );

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(ICommitteeRegistry.MemberNotInCommittee.selector, committeeId, notCommitteeMember)
        );

        // Act
        vm.prank(notCommitteeMember);
        registry.depositAggregatedKey(committeeId, COMMITTEE_PUB_KEY());
    }

    function test_depositAggregatedKey_Revert_InvalidAggregatedKeyLength() external {
        // Arrange
        (, uint128 committeeId) = setup_pendingCommittee();

        // Assert
        vm.expectRevert(abi.encodeWithSelector(ICommitteeRegistry.InvalidAggregatedKeyLength.selector, 0, 33));

        // Act
        vm.prank(vm.addr(1));
        registry.depositAggregatedKey(committeeId, new bytes(0));
    }

    function test_depositAggregatedKey_Revert_InvalidAggregatedKeyZero() external {
        // Arrange
        (, uint128 committeeId) = setup_pendingCommittee();
        bytes memory zeroKey = new bytes(33); // All zeros, 33 bytes

        // Assert
        vm.expectRevert(abi.encodeWithSelector(ICommitteeRegistry.InvalidAggregatedKeyZero.selector));

        // Act
        vm.prank(vm.addr(1));
        registry.depositAggregatedKey(committeeId, zeroKey);
    }

    function test_depositAggregatedKey_Revert_CommitteeIsNotPending() external {
        // Arrange
        uint128 committeeId = 1;

        // Assert
        vm.expectRevert(abi.encodeWithSelector(ICommitteeRegistry.CommitteeIsNotPending.selector, committeeId));

        // Act
        vm.prank(vm.addr(1));
        registry.depositAggregatedKey(committeeId, COMMITTEE_PUB_KEY());
    }

    function test_depositAggregatedKey_WrongCommitteeKey() external {
        // Arrange
        (, uint128 committeeId) = setup_pendingCommittee();
        setup_depositAggregatedKey(committeeId, vm.addr(1));
        bytes memory wrongPubKey =
            abi.encodePacked(bytes1(0x03), bytes32(0x1908421cb37d204b0c68660d093534d50d01fa791a3313e5fd9c21da137785ec));
        Committee memory expectedCommittee = setup_getExpectedCommitteeAfterExpire();
        vm.warp(BLOCK_COMMITTEE_3);
        vm.roll(BLOCK_COMMITTEE_3);

        // Assert
        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.NewPendingCommittee(COMMITTEE_ID_STREAM_1_COMMITTEE_3, expectedCommittee);

        // Act
        // Second member deposit wrong committee aggregated key, so discard current pending committee a create a new one.
        vm.prank(vm.addr(2));
        registry.depositAggregatedKey(committeeId, wrongPubKey);

        // Assert
        Committee memory committee = registry.getPendingCommittee(expectedCommittee.streamId);
        assertEqCommittee(committee, expectedCommittee, "get pending committee");
        assertNotEq(committee.createdAt, 0);
        assertEq(committee.missingData, registry.committeeMemberCount());
    }

    function test_depositAggregatedKey_Success_CompleteCommittee() external {
        // Arrange
        (Committee memory expectedCommittee, uint128 committeeId) = setup_pendingCommittee();
        expectedCommittee.aggregatedKey = COMMITTEE_PUB_KEY();
        expectedCommittee.missingData = 0;
        expectedCommittee.isPending = false;
        uint256 memberIndexStart = 0;
        uint256 memberCount = registry.committeeMemberCount() - 1;
        setup_depositAggregatedKey_MultipleMembers(committeeId, memberIndexStart, memberCount);

        // Assert
        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.NewCommittee(COMMITTEE_ID_STREAM_1_COMMITTEE_1, expectedCommittee);

        // Act
        // Member address is vm.address(memberIndex + 1);
        vm.prank(vm.addr(registry.committeeMemberCount()));
        registry.depositAggregatedKey(committeeId, COMMITTEE_PUB_KEY());

        assertEq(
            memberRegistry.getCommitteeCandidates(StreamDenomination(expectedCommittee.streamId), Role.OPERATOR).length,
            0,
            "Should not have candidates after committee created"
        );
        assertEq(
            memberRegistry.getCommitteeCandidates(StreamDenomination(expectedCommittee.streamId), Role.WATCHTOWER)
                .length,
            0,
            "Should not have candidates after committee created"
        );
    }

    function test_getPendingCommittee_Revert_CommitteeIsNotPending_AfterCompleteCommittee() external {
        // Arrange
        (Committee memory expectedCommittee, uint128 committeeId) = setup_pendingCommittee();
        uint256 memberIndexStart = 0;
        uint256 memberCount = registry.committeeMemberCount();
        setup_depositAggregatedKey_MultipleMembers(committeeId, memberIndexStart, memberCount);

        // Assert
        vm.expectRevert(abi.encodeWithSelector(ICommitteeRegistry.CommitteeIsNotPending.selector, 0));
        // Act
        registry.getPendingCommittee(expectedCommittee.streamId);
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
        (Committee memory expectedCommittee, uint128 committeeId) = setup_pendingCommittee();
        expectedCommittee.aggregatedKey = COMMITTEE_PUB_KEY();
        setup_depositAggregatedKey(committeeId, vm.addr(1));

        // Act
        bool isCommitteePendingExpired = registry.isPendingCommitteeExpired(expectedCommittee.streamId);

        // Assert
        // There is pending committee and it's not expired
        assertFalse(isCommitteePendingExpired, "pending committee is expired");
    }

    function test_isPendingCommitteeExpired_False_AfterSomeSeconds() external {
        // Arrange
        (Committee memory expectedCommittee, uint128 committeeId) = setup_pendingCommittee();
        expectedCommittee.aggregatedKey = COMMITTEE_PUB_KEY();
        setup_depositAggregatedKey(committeeId, vm.addr(1));
        vm.warp(block.timestamp + 60 seconds); // warp time but amount of time is not enough to expire the committee

        // Act
        bool isCommitteePendingExpired = registry.isPendingCommitteeExpired(expectedCommittee.streamId);

        // Assert
        // There is pending committee and it's not expired
        assertFalse(isCommitteePendingExpired, "pending committee is expired");
    }

    function test_isPendingCommitteeExpired_True_ChangingTimeout() external {
        // Arrange
        (Committee memory expectedCommittee,) = setup_pendingCommittee();
        vm.warp(block.timestamp + 60 seconds); // warp time to make committee expired

        // Act
        vm.prank(address(registry.owner()));
        registry.setPendingCommitteeTimeout(30 seconds);

        // Assert
        bool isCommitteePendingExpired = registry.isPendingCommitteeExpired(expectedCommittee.streamId);
        assertTrue(isCommitteePendingExpired, "pending committee is not expired");
    }

    function test_isPendingCommitteeExpired_True_AfterTimeout() external {
        // Arrange
        (Committee memory expectedCommittee,) = setup_pendingCommittee();
        uint256 timeout = registry.pendingCommitteeTimeout();
        vm.warp(block.timestamp + timeout + 1 seconds); // warp time to make committee expired

        // Act
        bool isCommitteePendingExpired = registry.isPendingCommitteeExpired(expectedCommittee.streamId);

        // Assert
        // There is pending committee and it's expired
        assertTrue(isCommitteePendingExpired, "pending committee is not expired");
    }

    function test_createCommittee_Success_AfterExpiredCommittee() external {
        // Arrange
        (Committee memory expectedCommittee,) = setup_pendingCommitteeAndExpire();

        // Assert
        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.NewPendingCommittee(COMMITTEE_ID_STREAM_1_COMMITTEE_3, expectedCommittee);

        // Act
        vm.prank(address(pm));
        registry.createCommittee(expectedCommittee.streamId);

        // Assert
        Committee memory committee = registry.getPendingCommittee(expectedCommittee.streamId);
        assertEqCommittee(committee, expectedCommittee, "get pending committee");
        assertNotEq(committee.createdAt, 0);
        assertEq(committee.missingData, registry.committeeMemberCount());
    }

    function test_depositAggregatedKey_Success_CompleteCommitteeOnExpiredCommittee() external {
        // Having an expired committee does not prevent members to still deposit their data
        // Arrange
        (Committee memory expectedCommittee, uint128 committeeId) = setup_pendingCommittee();
        uint256 timeout = registry.pendingCommitteeTimeout();
        vm.warp(block.timestamp + timeout + 1 seconds); // warp time to make committee expired
        expectedCommittee.aggregatedKey = COMMITTEE_PUB_KEY();
        expectedCommittee.missingData = 0;
        expectedCommittee.isPending = false;
        uint256 memberIndexStart = 0;
        uint256 memberCount = registry.committeeMemberCount() - 1;
        setup_depositAggregatedKey_MultipleMembers(committeeId, memberIndexStart, memberCount);

        // Assert
        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.NewCommittee(COMMITTEE_ID_STREAM_1_COMMITTEE_1, expectedCommittee);

        // Act
        // Member address is vm.address(memberIndex + 1);
        vm.prank(vm.addr(registry.committeeMemberCount()));
        registry.depositAggregatedKey(committeeId, COMMITTEE_PUB_KEY());

        // Assert
        vm.expectRevert(abi.encodeWithSelector(ICommitteeRegistry.CommitteeIsNotPending.selector, 0));
        // Act
        registry.getPendingCommittee(expectedCommittee.streamId);

        assertEq(
            memberRegistry.getCommitteeCandidates(StreamDenomination(expectedCommittee.streamId), Role.OPERATOR).length,
            0,
            "Should not have candidates after committee created"
        );
        assertEq(
            memberRegistry.getCommitteeCandidates(StreamDenomination(expectedCommittee.streamId), Role.WATCHTOWER)
                .length,
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
        (Committee memory expectedCommittee, uint128 committeeId) = setup_pendingCommittee();
        setup_depositAggregatedKey(committeeId, vm.addr(1));

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                ICommitteeRegistry.PendingCommitteeNotExpired.selector,
                expectedCommittee.streamId,
                BLOCK_COMMITTEE_1,
                86410
            )
        );

        // Act
        registry.restartPendingCommittee(expectedCommittee.streamId);
    }

    function test_restartPendingCommittee_Success() external {
        // Arrange
        (Committee memory expectedCommittee,) = setup_pendingCommitteeAndExpire();

        // Assert
        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.NewPendingCommittee(COMMITTEE_ID_STREAM_1_COMMITTEE_3, expectedCommittee);

        // Act
        registry.restartPendingCommittee(expectedCommittee.streamId);

        // Assert
        Committee memory committee = registry.getPendingCommittee(expectedCommittee.streamId);
        assertEqCommittee(committee, expectedCommittee, "get pending committee after restart");
        assertNotEq(committee.createdAt, 0);
        assertEq(
            committee.missingData,
            registry.committeeMemberCount(),
            "missing data should be equal to min committee members"
        );
        assertFalse(
            registry.shouldCreateCommitteeHarness(expectedCommittee.streamId),
            "Should not create committee after committee created"
        );
    }

    function test_setup_pendingCommitteeAndExpire() internal {
        // Test helper function to setup a pending committee and then expire it

        // Arrange
        // This function sets up a pending committee and then expires it
        (Committee memory expectedCommittee,) = setup_pendingCommitteeAndExpire();
        // We ask for current pending committee
        Committee memory currentPendingCommittee = registry.getPendingCommittee(expectedCommittee.streamId);

        assertEq(
            expectedCommittee.members.length,
            currentPendingCommittee.members.length,
            "Pending committee length should match. They are always the MIN_MEMBERS_COMMITTEE"
        );
        for (uint256 i = 0; i < expectedCommittee.members.length; i++) {
            assertNotEq(
                expectedCommittee.members[i].memberAddress,
                currentPendingCommittee.members[i].memberAddress,
                "Pending committee member should not match"
            );
        }
        assertFalse(
            registry.shouldCreateCommitteeHarness(expectedCommittee.streamId),
            "Flag shouldCreateCommittee should be false before it's called by PegManager"
        );

        // Act
        vm.prank(address(pm));
        registry.createCommitteeHarness(expectedCommittee.streamId);

        Committee memory pendingCommitteeAfterCall = registry.getPendingCommittee(expectedCommittee.streamId);
        assertNotEq(
            currentPendingCommittee.createdAt, pendingCommitteeAfterCall.createdAt, "Pending committee should change"
        );
        assertEq(pendingCommitteeAfterCall.missingData, 0, "Missing data should be 0 after committee creation");
        assertEq(
            new bytes(0),
            pendingCommitteeAfterCall.aggregatedKey,
            "Pending committee aggregated key should be empty after committee creation"
        );
        assertEqCommittee(
            expectedCommittee,
            pendingCommitteeAfterCall,
            "New pending committee should match that one returned by setup_pendingCommitteeAndExpire"
        );
        assertFalse(
            registry.shouldCreateCommitteeHarness(expectedCommittee.streamId),
            "Should not create committee after committee created"
        );
    }

    function test_createCommitteeAfterApplyToStream_Success_NotExpiredPendingCommittee() external {
        // Arrange
        (Committee memory expectedCommittee,) = setup_pendingCommittee();
        StreamDenomination denomination = StreamDenomination(expectedCommittee.streamId);
        Committee memory pendingCommitteeBeforeCall = registry.getPendingCommittee(expectedCommittee.streamId);
        vm.recordLogs();

        // createCommitteeAfterApplyToStream called should do nothing if pending committee is not expired
        // Act
        registry.createCommitteeAfterApplyToStreamHarness(denomination);

        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertEq(logs.length, 0, "Expected no events to be emitted");

        Committee memory pendingCommitteeAfterCall = registry.getPendingCommittee(expectedCommittee.streamId);
        assertEq(
            pendingCommitteeAfterCall.createdAt,
            pendingCommitteeBeforeCall.createdAt,
            "Pending committee should not change"
        );
        assertEq(
            pendingCommitteeAfterCall.missingData,
            pendingCommitteeBeforeCall.missingData,
            "Pending committee should not change"
        );
        assertEq(
            pendingCommitteeAfterCall.aggregatedKey,
            expectedCommittee.aggregatedKey,
            "Pending committee should not change"
        );
        assertEqCommitteeMembers(
            pendingCommitteeAfterCall.members, expectedCommittee.members, "Create committee should not change members"
        );
    }

    function test_createCommitteeAfterApplyToStream_Success_ExpiredPendingCommittee() external {
        // Arrange
        (Committee memory expectedCommittee,) = setup_pendingCommitteeAndExpire();
        StreamDenomination denomination = StreamDenomination(expectedCommittee.streamId);
        Committee memory pendingCommitteeBeforeCall2 = registry.getPendingCommittee(expectedCommittee.streamId);

        // Assert
        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.NewPendingCommittee(COMMITTEE_ID_STREAM_1_COMMITTEE_3, expectedCommittee);

        // createCommitteeAfterApplyToStream called should create a new pending committee if the previous one is expired
        // Act
        registry.createCommitteeAfterApplyToStreamHarness(denomination);

        Committee memory pendingCommitteeAfterCall = registry.getPendingCommittee(expectedCommittee.streamId);
        assertEq(
            pendingCommitteeAfterCall.missingData,
            expectedCommittee.members.length,
            "Pending committee should not change"
        );
        assertNotEq(
            pendingCommitteeBeforeCall2.createdAt,
            pendingCommitteeAfterCall.createdAt,
            "Pending committee should change"
        );
        assertEq(
            pendingCommitteeAfterCall.aggregatedKey,
            expectedCommittee.aggregatedKey,
            "Pending committee should not change"
        );
        assertEqCommitteeMembers(
            pendingCommitteeAfterCall.members, expectedCommittee.members, "Create committee should not change members"
        );
    }

    function test_createCommitteeAfterApplyToStream_Success_NoCommitteeForCurrentPacket() external {
        // In this case we want to test the case where we run out of slots from current packet without being ables to create a new pending committee.
        // This is a edge case where we had the minimum of members to create first packet but one of the members decided to unsubscribe from the stream for next packet
        // So pending committee wont be created in each of the last pegins of current packet. Resulting in no pending committee for next packet.
        // applyToStream call internally to `createCommitteeAfterApplyToStream`

        // ===== Arrange start =====
        // Create a complete committee for initial packet
        setup_completeCommitteeAndNewMembers();
        uint64 streamId = SETUP_PENDING_COMMITTEE_STREAM_ID;
        StreamDenomination denomination = StreamDenomination(streamId);
        // Need to use last member in the committee to unsubscribe and subscribe to keep same random committee member order
        uint256 userIndex = registry.committeeMemberCount() * 2 - 1;
        Role userRole = Role.OPERATOR;
        address userAddress = vm.addr(userIndex + 1);
        MemberRegistrationKeys memory memberRegistrationKeys =
            generateRegistrationPublicKeys(uint256(uint160(userAddress)));

        // Unsubscribe one of the members
        vm.prank(userAddress);
        registry.unsubscribeFromStream(denomination);

        // Use all the slots in the packet
        setup_multipleRequestAndAcceptPeginFlows(Constants.SLOTS_PER_PACKET);

        Stream memory stream = streamManager.getStreamById(streamId);
        assertEq(stream.peginPacketPointer, 1, "Stream pegin packet pointer should be 1 after filling all slots");

        // Check that current packet does not have a committee
        uint256 currentPacketCommitteeId = streamManager.getAvailablePeginCommitteeId(streamId);
        assertEq(currentPacketCommitteeId, 0, "Current packet committee ID should be 0 when no committee exists");

        // Check there is no pending committee
        vm.expectRevert(abi.encodeWithSelector(ICommitteeRegistry.CommitteeIsNotPending.selector, 0));
        registry.getPendingCommittee(streamId);

        uint256 minimumDeposit = streamManager.getMinimumDeposit(denomination, userRole);
        vm.deal(userAddress, minimumDeposit);
        Committee memory expectedCommittee = setup_getExpectedSecondCommittee();
        vm.warp(BLOCK_COMMITTEE_2);
        assertTrue(
            registry.shouldCreateCommitteeHarness(streamId),
            "Flag should be true because there is no pending committee and need one to new packet"
        );
        // ===== Arrange end =====

        // Assert
        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.NewPendingCommittee(COMMITTEE_ID_STREAM_1_COMMITTEE_2, expectedCommittee);

        // Act
        vm.prank(userAddress);
        registry.applyToStream{value: minimumDeposit}(
            denomination, userRole, memberRegistrationKeys, generateDefaultUTXO()
        );

        // Assert
        Committee memory pendingCommittee = registry.getPendingCommittee(streamId);
        assertEqCommittee(pendingCommittee, expectedCommittee, "get pending committee after apply to stream");
        assertNotEq(pendingCommittee.createdAt, 0, "Created at should not be 0 after apply to stream");
        assertEq(
            pendingCommittee.missingData,
            registry.committeeMemberCount(),
            "Missing data should be equal to min committee members"
        );
        assertFalse(registry.shouldCreateCommitteeHarness(streamId), "Flag should be false before createCommittee call");
    }

    function test_applyToStream_Revert_TooManyCandidatesForStream_Operator() external {
        // Arrange
        StreamDenomination denomination = StreamDenomination._0_01BTC;
        Role role = Role.OPERATOR;
        setup_registerNewMembers(0, Constants.MAX_CANDIDATES_SIZE_PER_ROLE, denomination);
        address memberAddress = vm.addr(Constants.MAX_CANDIDATES_SIZE_PER_ROLE + 1);
        MemberRegistrationKeys memory publicKeysRegistration =
            generateRegistrationPublicKeys(uint256(uint160(memberAddress)));
        uint256 minimumDeposit = streamManager.getMinimumDeposit(denomination, role);
        vm.deal(memberAddress, minimumDeposit);

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IMemberRegistry.TooManyCandidatesForStream.selector, denomination, role));

        // Act
        vm.prank(memberAddress);
        registry.applyToStream{value: minimumDeposit}(denomination, role, publicKeysRegistration, generateDefaultUTXO());
    }

    function test_applyToStream_Revert_TooManyCandidatesForStream_Watchtower() external {
        // Arrange
        StreamDenomination denomination = StreamDenomination._0_01BTC;
        Role role = Role.WATCHTOWER;
        setup_registerNewMembers(Constants.MAX_CANDIDATES_SIZE_PER_ROLE, 0, denomination);
        address memberAddress = vm.addr(Constants.MAX_CANDIDATES_SIZE_PER_ROLE + 1);
        MemberRegistrationKeys memory publicKeysRegistration =
            generateRegistrationPublicKeys(uint256(uint160(memberAddress)));
        uint256 minimumDeposit = streamManager.getMinimumDeposit(denomination, role);
        vm.deal(memberAddress, minimumDeposit);

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IMemberRegistry.TooManyCandidatesForStream.selector, denomination, role));

        // Act
        vm.prank(memberAddress);
        registry.applyToStream{value: minimumDeposit}(denomination, role, publicKeysRegistration, generateDefaultUTXO());
    }

    function test_unsubscribeFromStream_GasConsumptionCheck() external {
        // This test is to measure the gas usage of the unsubscribeFromStream function
        // based on different values of Constants.MAX_CANDIDATES_SIZE_PER_ROLE
        // unsubscribeFromStream iterate over all the candidates in the stream until it finds the member to unsubscribe.
        // Results:
        // Constants.MAX_CANDIDATES_SIZE_PER_ROLE = 100: 69k gas
        // Constants.MAX_CANDIDATES_SIZE_PER_ROLE = 250: 127k gas
        // Constants.MAX_CANDIDATES_SIZE_PER_ROLE = 256: 129k gas
        // Constants.MAX_CANDIDATES_SIZE_PER_ROLE = 500: 224k gas
        // Constants.MAX_CANDIDATES_SIZE_PER_ROLE = 512: 228k gas
        // Constants.MAX_CANDIDATES_SIZE_PER_ROLE = 1000: 418k gas

        // Arrange
        StreamDenomination denomination = StreamDenomination._0_01BTC;
        setup_registerNewMembers(Constants.MAX_CANDIDATES_SIZE_PER_ROLE, 0, denomination);
        address lastMemberAddress = vm.addr(Constants.MAX_CANDIDATES_SIZE_PER_ROLE);
        uint256 gasStart = gasleft();

        // Act
        vm.prank(lastMemberAddress);
        registry.unsubscribeFromStream(denomination);
        uint256 gasUsed = gasStart - gasleft();

        assertTrue(
            gasUsed < MAX_GAS_PER_COMMITTEE_CREATION / registry.committeeMemberCount(),
            "Gas usage should not exceed MAX_GAS_PER_COMMITTEE_CREATION divided by committeeMemberCount"
        );
    }

    function test_createCommittee_GasConsumptionCheck() external {
        // This test is to measure the gas usage of the createCommittee function
        // in the worst case scenario when all the candidates are registered
        // and the committee is created with last candidates of the array.
        // So to remove them it's needed to iterate over all the candidates.
        // Results:
        // Constants.MAX_CANDIDATES_SIZE_PER_ROLE = 10: 701k gas
        // Constants.MAX_CANDIDATES_SIZE_PER_ROLE = 100: 1.051M gas
        // Constants.MAX_CANDIDATES_SIZE_PER_ROLE = 200: 1.439M gas
        // Constants.MAX_CANDIDATES_SIZE_PER_ROLE = 250: 1.633M gas
        // Constants.MAX_CANDIDATES_SIZE_PER_ROLE = 256: 1.656M gas
        // Constants.MAX_CANDIDATES_SIZE_PER_ROLE = 500: 2.603M gas
        // Constants.MAX_CANDIDATES_SIZE_PER_ROLE = 512: 2.649M gas

        // Arrange
        StreamDenomination denomination = StreamDenomination._0_01BTC;
        uint64 streamId = uint64(denomination);
        setup_registerNewMembers(
            Constants.MAX_CANDIDATES_SIZE_PER_ROLE, Constants.MAX_CANDIDATES_SIZE_PER_ROLE, denomination
        );

        // Create a pending committee
        uint256 numOperators = registry.committeeMemberCount() / 2;
        uint256 numWatchtowers = registry.committeeMemberCount() / 2;
        (CommitteeMember[] memory members, uint128 committeeId) =
            registry.createCommitteeWithLastCandidatesHarness(streamId, numWatchtowers, numOperators);

        assertEq(
            members.length,
            numWatchtowers + numOperators,
            "Members length should match the sum of operators and watchtowers"
        );

        for (uint256 i = 0; i < members.length - 1; i++) {
            setup_depositAggregatedKey(committeeId, members[i].memberAddress);
        }
        address lastMemberAddress = members[members.length - 1].memberAddress;

        vm.expectEmit(address(streamManager));
        emit IStreamManager.PacketCreated(streamId, 0);

        // Act
        uint256 gasStart = gasleft();
        vm.prank(lastMemberAddress);
        registry.depositAggregatedKey(committeeId, COMMITTEE_PUB_KEY());
        uint256 gasUsed = gasStart - gasleft();

        // Assert
        assertLt(gasUsed, MAX_GAS_PER_COMMITTEE_CREATION, "Gas usage should not exceed MAX_GAS_PER_COMMITTEE_CREATION");
    }

    function test_removeCandidatesAndUpdateBalance_GasConsumptionCheck() external {
        // This test is to measure the gas usage of the removeCandidatesAndUpdateBalanceHarness function
        // in the worst case scenario when all the candidates are registered
        // and the committee is created with last candidates of the array.
        // So to remove them it's needed to iterate over all the candidates.
        // Results:
        // Constants.MAX_CANDIDATES_SIZE_PER_ROLE = 10: 303k gas
        // Constants.MAX_CANDIDATES_SIZE_PER_ROLE = 100: 655k gas
        // Constants.MAX_CANDIDATES_SIZE_PER_ROLE = 200: 1.045M gas
        // Constants.MAX_CANDIDATES_SIZE_PER_ROLE = 250: 1.240M gas
        // Constants.MAX_CANDIDATES_SIZE_PER_ROLE = 256: 1.263M gas
        // Constants.MAX_CANDIDATES_SIZE_PER_ROLE = 500: 2.215M gas
        // Constants.MAX_CANDIDATES_SIZE_PER_ROLE = 512: 2.262M gas

        // Arrange
        StreamDenomination denomination = StreamDenomination._0_01BTC;
        uint64 streamId = uint64(denomination);
        setup_registerNewMembers(
            Constants.MAX_CANDIDATES_SIZE_PER_ROLE, Constants.MAX_CANDIDATES_SIZE_PER_ROLE, denomination
        );

        // Create a pending committee
        uint256 numOperators = registry.committeeMemberCount() / 2;
        uint256 numWatchtowers = registry.committeeMemberCount() / 2;
        (CommitteeMember[] memory members,) =
            registry.createCommitteeWithLastCandidatesHarness(streamId, numWatchtowers, numOperators);

        // Act
        uint256 gasStart = gasleft();
        registry.removeCandidatesAndUpdateBalanceHarness(members, denomination, 0);
        uint256 gasUsed = gasStart - gasleft();

        // Assert
        assertTrue(
            gasUsed < MAX_GAS_PER_COMMITTEE_CREATION, "Gas usage should not exceed MAX_GAS_PER_COMMITTEE_CREATION"
        );
    }

    function test_depositCommunicationData_Success() public {
        // Arrange
        (Committee memory expectedCommittee, uint128 committeeId) = setup_pendingCommittee();
        uint256 memberIndex = 0;
        address memberAddress = expectedCommittee.members[memberIndex].memberAddress;

        CommunicationData[] memory communicationData =
            createValidCommunicationData(expectedCommittee.members.length, memberIndex);

        // Assert
        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.MemberCommunicationDataDeposited(committeeId, memberAddress, communicationData);

        // Act
        vm.prank(memberAddress);
        registry.depositCommunicationData(committeeId, communicationData);

        // Assert - verify data was stored correctly using harness
        CommunicationData[] memory storedData =
            registry.getStoredCommunicationDataHarness(expectedCommittee.streamId, memberAddress);

        assertCommunicationDataEqual(communicationData, storedData, "Stored data should match deposited data");
    }

    function test_depositCommunicationData_Success_MinData() public {
        // Arrange
        (Committee memory expectedCommittee, uint128 committeeId) = setup_pendingCommittee();
        uint256 memberIndex = 0;
        address memberAddress = expectedCommittee.members[memberIndex].memberAddress;

        // Create minimal communication data using helper function
        CommunicationData[] memory communicationData =
            createMinimalCommunicationData(expectedCommittee.members.length, memberIndex);

        // Act
        vm.prank(memberAddress);
        registry.depositCommunicationData(committeeId, communicationData);

        // Assert - verify minimal data was stored correctly
        CommunicationData[] memory storedData =
            registry.getStoredCommunicationDataHarness(expectedCommittee.streamId, memberAddress);

        assertCommunicationDataEqual(communicationData, storedData, "Minimal data should be stored correctly");
    }

    function test_depositCommunicationData_Revert_MemberNotInCommittee() public {
        // Arrange
        (Committee memory expectedCommittee, uint128 committeeId) = setup_pendingCommittee();
        address nonMemberAddress = vm.addr(999); // Address not in committee
        CommunicationData[] memory communicationData = createValidCommunicationData(expectedCommittee.members.length, 0);

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(ICommitteeRegistry.MemberNotInCommittee.selector, committeeId, nonMemberAddress)
        );

        // Act
        vm.prank(nonMemberAddress);
        registry.depositCommunicationData(committeeId, communicationData);
    }

    function test_depositCommunicationData_Revert_MemberNotInCommittee_butRegistered() public {
        // Arrange
        (Committee memory expectedCommittee, uint128 committeeId) = setup_pendingCommittee();
        uint256 privKey = 999;
        address registeredToAnotherStreamMemberAddress = vm.addr(privKey); // Address not in committee

        MemberRegistrationKeys memory publicKeysRegistration = generateRegistrationPublicKeys(privKey);

        setup_applyToStream(
            StreamDenomination._0_1BTC, registeredToAnotherStreamMemberAddress, publicKeysRegistration, Role.OPERATOR
        );
        CommunicationData[] memory communicationData = createValidCommunicationData(expectedCommittee.members.length, 0);

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                ICommitteeRegistry.MemberNotInCommittee.selector, committeeId, registeredToAnotherStreamMemberAddress
            )
        );

        // Act
        vm.prank(registeredToAnotherStreamMemberAddress);
        registry.depositCommunicationData(committeeId, communicationData);
    }

    function test_depositCommunicationData_Revert_InvalidCommunicationDataLength() public {
        // Arrange
        (Committee memory expectedCommittee, uint128 committeeId) = setup_pendingCommittee();
        address memberAddress = vm.addr(1);

        // Create communication data with wrong length (committee size - 1)
        uint256 wrongLength = expectedCommittee.members.length - 1;
        CommunicationData[] memory wrongLengthData = new CommunicationData[](wrongLength);

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                ICommitteeRegistry.InvalidCommunicationDataLength.selector,
                wrongLength,
                expectedCommittee.members.length
            )
        );

        // Act
        vm.prank(memberAddress);
        registry.depositCommunicationData(committeeId, wrongLengthData);
    }

    function test_depositCommunicationData_Revert_InvalidNonZeroCommunicationData() public {
        // Arrange
        (Committee memory expectedCommittee, uint128 committeeId) = setup_pendingCommittee();
        uint256 memberIndex = 0;
        address memberAddress = expectedCommittee.members[memberIndex].memberAddress;

        // Create communication data with non-zero data in own slot (should be zero)
        CommunicationData[] memory communicationData =
            createValidCommunicationData(expectedCommittee.members.length, memberIndex);

        // Put non-zero data in member's own slot
        communicationData[memberIndex].data[0] = bytes32(uint256(1));

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                ICommitteeRegistry.InvalidNonZeroCommunicationData.selector, memberIndex, communicationData[memberIndex]
            )
        );

        // Act
        vm.prank(memberAddress);
        registry.depositCommunicationData(committeeId, communicationData);
    }

    function test_depositCommunicationData_Revert_InvalidZeroCommunicationData() public {
        // Arrange
        (Committee memory expectedCommittee, uint128 committeeId) = setup_pendingCommittee();
        uint256 memberIndex = 0;
        address memberAddress = expectedCommittee.members[memberIndex].memberAddress;

        // Create communication data with zero data in another member's slot (should be non-zero)
        CommunicationData[] memory communicationData =
            createValidCommunicationData(expectedCommittee.members.length, memberIndex);

        // Clear data for another member's slot (pick the first non-member slot)
        uint256 otherMemberIndex = memberIndex == 0 ? 1 : 0;
        for (uint256 i = 0; i < COMMUNICATION_DATA_CHUNKS; i++) {
            communicationData[otherMemberIndex].data[i] = bytes32(0);
        }

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                ICommitteeRegistry.InvalidZeroCommunicationData.selector,
                otherMemberIndex,
                communicationData[otherMemberIndex]
            )
        );

        // Act
        vm.prank(memberAddress);
        registry.depositCommunicationData(committeeId, communicationData);
    }

    function test_depositCommunicationData_Revert_MemberAlreadyDepositedCommunicationData() public {
        // Arrange
        (Committee memory expectedCommittee, uint128 committeeId) = setup_pendingCommittee();
        uint256 memberIndex = 0;
        address memberAddress = expectedCommittee.members[memberIndex].memberAddress;

        CommunicationData[] memory communicationData =
            createValidCommunicationData(expectedCommittee.members.length, memberIndex);

        // First deposit should succeed
        vm.prank(memberAddress);
        registry.depositCommunicationData(committeeId, communicationData);

        // Assert - second deposit should revert
        vm.expectRevert(
            abi.encodeWithSelector(
                ICommitteeRegistry.MemberAlreadyDepositedCommunicationData.selector,
                committeeId,
                memberAddress,
                expectedCommittee.members.length
            )
        );

        // Act - try to deposit again
        vm.prank(memberAddress);
        registry.depositCommunicationData(committeeId, communicationData);
    }

    function test_depositCommunicationData_Revert_CommitteeIsNotPending() public {
        // Arrange
        uint64 noPendingCommitteeStreamId = 0; // Stream without pending committee
        address memberAddress = vm.addr(1);
        CommunicationData[] memory communicationData = new CommunicationData[](10); // Dummy data

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(ICommitteeRegistry.CommitteeIsNotPending.selector, noPendingCommitteeStreamId)
        );

        // Act
        vm.prank(memberAddress);
        registry.depositCommunicationData(noPendingCommitteeStreamId, communicationData);
    }

    function test_depositCommunicationData_Success_AllMembersDeposit_EmitsAllCommunicationDataReady() public {
        // Arrange
        (Committee memory expectedCommittee, uint128 committeeId) = setup_pendingCommittee();
        uint256 memberCount = expectedCommittee.members.length;

        // Deposit all communication data except the last one
        for (uint256 i = 0; i < memberCount - 1; i++) {
            address memberAddress = expectedCommittee.members[i].memberAddress;
            CommunicationData[] memory communicationData = createValidCommunicationData(memberCount, i);

            vm.prank(memberAddress);
            registry.depositCommunicationData(committeeId, communicationData);
        }

        // Verify counter before final deposit
        uint16 missingCount = registry.getMissingCommunicationDataCount(committeeId);
        assertEq(missingCount, 1, "Should have 1 missing communication data before final deposit");

        // Prepare final member data
        address lastMemberAddress = expectedCommittee.members[memberCount - 1].memberAddress;
        CommunicationData[] memory lastCommunicationData = createValidCommunicationData(memberCount, memberCount - 1);

        // Assert that AllCommunicationDataReady event is emitted when the last member deposits
        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.AllCommunicationDataReady(committeeId);

        // Act - deposit the final communication data
        vm.prank(lastMemberAddress);
        registry.depositCommunicationData(committeeId, lastCommunicationData);

        // Assert counter is now zero
        uint16 finalMissingCount = registry.getMissingCommunicationDataCount(committeeId);
        assertEq(finalMissingCount, 0, "Should have 0 missing communication data after all deposits");
    }

    function test_getMemberCommunicationData_Success() public {
        // Arrange
        (Committee memory expectedCommittee, uint128 committeeId) = setup_pendingCommittee();
        uint256 memberIndex = 0;
        address memberAddress = expectedCommittee.members[memberIndex].memberAddress;

        // Create expected communication data that other members should have deposited for this member
        CommunicationData[] memory expectedData =
            createValidCommunicationData(expectedCommittee.members.length, memberIndex);

        // Use harness to simulate that all other members have deposited data for this member
        registry.setCommunicationDataForMemberHarness(expectedCommittee.streamId, memberIndex, expectedData);

        // Act
        vm.prank(memberAddress);
        CommunicationData[] memory retrievedData = registry.getMemberCommunicationData(committeeId, memberAddress);

        // Assert
        assertCommunicationDataEqual(expectedData, retrievedData, "Retrieved data should match expected data");
    }

    function test_getMemberCommunicationData_Revert_MemberNotInCommittee() public {
        // Arrange
        (, uint128 committeeId) = setup_pendingCommittee();

        uint256 privKey = 999;
        address memberAddressForOtherStream = vm.addr(privKey); // Address not in  pending committee
        MemberRegistrationKeys memory publicKeysRegistration = generateRegistrationPublicKeys(privKey);

        setup_applyToStream(
            StreamDenomination._0_1BTC, memberAddressForOtherStream, publicKeysRegistration, Role.OPERATOR
        );

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                ICommitteeRegistry.MemberNotInCommittee.selector, committeeId, memberAddressForOtherStream
            )
        );

        // Act
        vm.prank(memberAddressForOtherStream);
        registry.getMemberCommunicationData(committeeId, memberAddressForOtherStream);
    }
}
