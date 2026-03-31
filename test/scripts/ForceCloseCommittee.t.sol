// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {CommitteeMember, Committee, ICommitteeRegistry} from "src/interfaces/ICommitteeRegistry.sol";
import {IMemberRegistry} from "src/interfaces/IMemberRegistry.sol";
import {StreamDenomination, IStreamManager, Stream} from "src/interfaces/IStreamManager.sol";
import {StreamPosition, PegStatus} from "src/interfaces/IPegCommonTypes.sol";
import {BtcHelper} from "src/libraries/BtcHelper.sol";
import {HelperContract} from "test/helpers/HelperContract.sol";
import {ForceCloseCommitteeScript} from "script/testnet/ForceCloseCommittee.s.sol";

contract ForceCloseCommitteeTest is Test, HelperContract {
    ForceCloseCommitteeScript forceCloseCommitteeScript;

    function setUp() external {
        runTestDeployScript();
        forceCloseCommitteeScript = new ForceCloseCommitteeScript();
        vm.roll(1000);
    }

    // ========================== TESTNET ONLY forceCloseCommittee ==========================

    function test_forceCloseCommittee_TESTNET_Success_NoActiveCommittees() external {
        // Arrange
        uint64 streamId = 1;

        // Act
        forceCloseCommitteeScript.run(streamId);

        // Assert — shouldCreateCommittee is true
        assertTrue(
            registry.shouldCreateCommitteeHarness(streamId), "shouldCreateCommittee should be true after force close"
        );
    }

    function test_forceCloseCommittee_TESTNET_Success_SingleActiveCommittee() external {
        // Arrange
        (, uint128 committeeId) = setup_completeCommittee();
        uint64 streamId = SETUP_PENDING_COMMITTEE_STREAM_ID;

        // Record member staked balances before force close
        CommitteeMember[] memory members = registry.getCommitteeMembers(committeeId);
        StreamDenomination denomination = StreamDenomination(streamId);
        uint64 packetNumber = 0;
        uint256[] memory stakedBefore = new uint256[](members.length);
        for (uint256 i = 0; i < members.length; i++) {
            stakedBefore[i] =
                memberRegistry.getMemberStakedBalance(members[i].memberAddress, denomination, packetNumber);
        }

        // Assert
        vm.expectEmit(address(memberRegistry));
        emit IMemberRegistry.CommitteeMembersForceReleased(streamId, packetNumber);
        vm.expectEmit(address(streamManager));
        emit IStreamManager.StreamPointersRestarted(streamId);

        // Act
        forceCloseCommitteeScript.run(streamId);

        // Assert — shouldCreateCommittee is true
        assertTrue(
            registry.shouldCreateCommitteeHarness(streamId), "shouldCreateCommittee should be true after force close"
        );

        // Assert — members got funds back (staked moved to available)
        for (uint256 i = 0; i < members.length; i++) {
            uint256 availableAfter = memberRegistry.getMemberAvailableBalance(members[i].memberAddress);
            uint256 stakedAfter = memberRegistry.getMemberStakedBalance(members[i].memberAddress, denomination, 0);
            assertEq(stakedAfter, 0, "Staked balance should be zero");
            assertEq(availableAfter, stakedBefore[i], "Available balance should equal previous staked");
        }

        // Assert
        Stream memory streamAfter = streamManager.getStreamById(streamId);
        // pegin packet pointer was advanced to the first "future" packet
        uint64 packetsLengthAfter = streamManager.getPacketsLength(streamId);
        assertEq(streamAfter.peginPacketPointer, packetsLengthAfter, "Pegin pointer should be at end of packets");
        // stream filled slots were cleaned
        assertEq(streamManager.getFilledSlots(streamId).length, 0, "No filled slots after force close");
    }

    function test_forceCloseCommittee_TESTNET_Success_ClearsPegoutInProcess() external {
        // Arrange
        (, uint128 committeeId) = setup_completeCommittee();
        uint64 streamId = SETUP_PENDING_COMMITTEE_STREAM_ID;

        RegisterUserTakeSetup memory setup = setup_peginAndSPVs(committeeId);
        vm.prank(globalUserAddress);
        pegoutManager.tryPegout{value: BtcHelper.satoshiToWei(VALUE)}(setup.userPubKey);

        // Act
        forceCloseCommitteeScript.run(streamId);

        // Assert
        assertFalse(streamManager.hasPegoutInProcess(streamId), "isPegoutInProcess should be false after force close");
    }

    function test_forceCloseCommittee_TESTNET_Success_SinglePendingCommittee() external {
        // Arrange
        (, uint128 pendingCommitteeId) = setup_pendingCommittee();
        uint64 streamId = SETUP_PENDING_COMMITTEE_STREAM_ID;

        // Record member staked balances before force close
        CommitteeMember[] memory members = registry.getCommitteeMembers(pendingCommitteeId);
        StreamDenomination denomination = StreamDenomination(streamId);
        uint64 packetNumber = 0;
        uint256[] memory preStakedBefore = new uint256[](members.length);
        for (uint256 i = 0; i < members.length; i++) {
            preStakedBefore[i] = memberRegistry.getMemberPreStakedBalance(members[i].memberAddress, denomination);
        }

        // Assert
        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.PendingCommitteeForceDiscarded(streamId, pendingCommitteeId);
        vm.expectEmit(address(streamManager));
        emit IStreamManager.StreamPointersRestarted(streamId);

        // Act
        forceCloseCommitteeScript.run(streamId);

        // Assert — shouldCreateCommittee is true
        assertTrue(
            registry.shouldCreateCommitteeHarness(streamId), "shouldCreateCommittee should be true after force close"
        );

        // Assert — members got funds back (staked moved to available)
        for (uint256 i = 0; i < members.length; i++) {
            uint256 availableAfter = memberRegistry.getMemberAvailableBalance(members[i].memberAddress);
            uint256 preStakedAfter = memberRegistry.getMemberPreStakedBalance(members[i].memberAddress, denomination);
            assertEq(preStakedAfter, 0, "Staked balance should be zero");
            assertEq(availableAfter, preStakedBefore[i], "Available balance should equal previous staked");
        }

        // Assert
        Stream memory streamAfter = streamManager.getStreamById(streamId);
        // pegin packet pointer was advanced to the first "future" packet
        uint64 packetsLengthAfter = streamManager.getPacketsLength(streamId);
        assertEq(streamAfter.peginPacketPointer, packetsLengthAfter, "Pegin pointer should be at end of packets");
        // stream filled slots were cleaned
        assertEq(streamManager.getFilledSlots(streamId).length, 0, "No filled slots after force close");
    }

    function test_forceCloseCommittee_TESTNET_Success_MultipleActiveCommittees() external {
        // Arrange
        (uint128 firstCommitteeId, uint128 secondCommitteeId, uint64 streamId) = setup_twoActiveCommittees();
        address owner = memberRegistry.owner();
        CommitteeMember[] memory members = registry.getCommitteeMembers(firstCommitteeId);

        // Assert
        vm.expectEmit(address(memberRegistry));
        emit IMemberRegistry.CommitteeMembersForceReleased(streamId, 0);
        vm.expectEmit(address(memberRegistry));
        emit IMemberRegistry.CommitteeMembersForceReleased(streamId, 1);
        vm.expectEmit(address(streamManager));
        emit IStreamManager.StreamPointersRestarted(streamId);

        // Act
        forceCloseCommitteeScript.run(streamId);

        // Assert
        assertTrue(
            registry.shouldCreateCommitteeHarness(streamId), "shouldCreateCommittee should be true after force close"
        );
        // stream filled slots were cleaned
        assertEq(streamManager.getFilledSlots(streamId).length, 0, "No filled slots after force close");
    }

    function test_forceCloseCommittee_TESTNET_Success_CreateNewCommitteeAfterForceClose() external {
        // Arrange — complete a committee and force close it
        setup_completeCommittee();
        uint64 streamId = SETUP_PENDING_COMMITTEE_STREAM_ID;
        uint64 packetsLengthBeforeNewCommittee = streamManager.getPacketsLength(streamId);

        forceCloseCommitteeScript.run(streamId);

        // Act — form a new committee after force close
        setup_completeAdditionalCommittee(BLOCK_COMMITTEE_2);

        // Assert
        // pegin packet pointer was advanced to the first "future" packet
        Stream memory stream = streamManager.getStreamById(streamId);
        assertEq(stream.peginPacketPointer, packetsLengthBeforeNewCommittee, "Pegin pointer should point to new packet");
        // active packets and stream filled slots were cleaned
        assertEq(
            streamManager.getPacketsLength(streamId),
            packetsLengthBeforeNewCommittee + 1,
            "Should be one active packet after creating new committee"
        );
        assertEq(streamManager.getFilledSlots(streamId).length, 0, "There should not be filled slots yet");
    }

    function test_forceCloseCommittee_TESTNET_Success_FullPegCycleAfterForceClose() external {
        // === Phase 1: Setup first committee and start a pegout ===
        (, uint128 firstCommitteeId) = setup_completeCommittee();
        uint64 streamId = SETUP_PENDING_COMMITTEE_STREAM_ID;

        RegisterUserTakeSetup memory firstSetup = setup_peginAndSPVs(firstCommitteeId);
        vm.prank(globalUserAddress);
        pegoutManager.tryPegout{value: BtcHelper.satoshiToWei(VALUE)}(firstSetup.userPubKey);

        // === Phase 2: Force-close committee 1 ===
        forceCloseCommitteeScript.run(streamId);

        // === Phase 3: Create a new committee ===
        uint128 newCommitteeId = setup_completeAdditionalCommittee(BLOCK_COMMITTEE_2);

        // === Phase 4: Full pegin → pegout happy path with the new committee ===
        RegisterUserTakeSetup memory setup = setup_peginAndSPVs(newCommitteeId);
        vm.prank(globalUserAddress);
        pegoutManager.tryPegout{value: BtcHelper.satoshiToWei(VALUE)}(setup.userPubKey);
        pegoutManager.registerUserTake(setup.pegoutTxSPVProof);

        // Assert peg cycle completed successfully
        StreamPosition memory streamPosition = streamManager.getStreamPosition(setup.acceptPeginTxid);
        assertTrue(
            streamPosition.pegStatus == PegStatus.COMPLETED, "Peg status should be COMPLETED after full peg cycle"
        );
    }

    function test_forceCloseCommittee_TESTNET_Success_SameMembersCanCreateCommittee() external {
        // Arrange — complete a committee and get the members
        (, uint128 firstCommitteeId) = setup_completeCommittee();
        uint64 streamId = SETUP_PENDING_COMMITTEE_STREAM_ID;
        StreamDenomination denomination = StreamDenomination(streamId);
        CommitteeMember[] memory originalMembers = registry.getCommitteeMembers(firstCommitteeId);

        // Force close the committee
        forceCloseCommitteeScript.run(streamId);

        vm.warp(BLOCK_COMMITTEE_2);
        vm.roll(BLOCK_COMMITTEE_2);

        // Act — same members reapply to the stream
        setup_applyToStream_MultipleMembers(denomination, originalMembers);

        // Get the new pending committee (created automatically when last member applied)
        uint128 newCommitteeId = registry.getPendingCommitteeId(streamId);
        CommitteeMember[] memory newMembers = registry.getCommitteeMembers(newCommitteeId);

        // Assert — all original members are in the new committee
        assertEqCommitteeMembersSet(newMembers, originalMembers);

        // Complete the new committee by depositing aggregated keys
        setup_depositAggregatedKey_MultipleMembers(newCommitteeId, 0, newMembers.length);

        // Assert — new committee is formed successfully
        Committee memory newCommittee = registry.getCommittee(newCommitteeId);
        assertFalse(newCommittee.isPending, "New committee should not be pending after all members deposit");
        assertEq(newCommittee.missingData, 0, "New committee should have no missing data");
    }
}
