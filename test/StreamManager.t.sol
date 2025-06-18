// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {HelperContract} from "test/helpers/HelperContract.sol";
import {SlotState, Slot, Packet, IStreamManager} from "src/interfaces/IStreamManager.sol";
import {Constants} from "src/libraries/Constants.sol";
import {BtcHelper} from "src/libraries/BtcHelper.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract TestStreamManager is Test, HelperContract {
    uint64 internal setupStreamId;

    function setUp() external {
        runTestDeployScript();
        (, setupStreamId) = setup_completeCommittee();
    }

    function test_lockSlot_Success() external {
        // Arrange
        streamManager.setSlotHarness(setupStreamId, 0, hex"00", 0, 0);

        // Act
        vm.prank(address(pm));
        (Slot memory slot,) = streamManager.lockSlot(setupStreamId);

        // Assert
        assertEq(uint64(slot.state), uint64(SlotState.LOCKED), "Incorrect slot state");
    }

    function test_lockSlot_NonExistentSlot() external {
        // Assert
        vm.expectRevert(abi.encodeWithSelector(IStreamManager.NonExistentSlot.selector, setupStreamId, 0, 0));

        // Act
        vm.prank(address(pm));
        streamManager.lockSlot(setupStreamId);
    }

    function test_lockSlot_InconsistentPegoutPointer() external {
        // Arrange
        streamManager.pushSlotsHarness(setupStreamId, 0, Constants.SLOTS_PER_PACKET + 1, SlotState.FILLED);
        streamManager.setPegoutPointersHarness(setupStreamId, 0, Constants.SLOTS_PER_PACKET);
        uint256 slotsLength = streamManager.getSlotsLengthHarness(setupStreamId, 0);
        assertEq(slotsLength, Constants.SLOTS_PER_PACKET + 1, "Incorrect slots length");

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(IStreamManager._InconsistentPegoutPointer.selector, setupStreamId, 0, 101)
        );

        // Act
        vm.prank(address(pm));
        streamManager.lockSlot(setupStreamId);
    }

    function test_lockSlot_NoFilledSlot() external {
        // Arrange
        streamManager.pushSlotsHarness(setupStreamId, 0, 1, SlotState.LOCKED);
        uint256 slotsLength = streamManager.getSlotsLengthHarness(setupStreamId, 0);
        assertEq(slotsLength, 1, "Incorrect slots length");

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IStreamManager.NoFilledSlot.selector, setupStreamId, 0, 0));

        // Act
        vm.prank(address(pm));
        streamManager.lockSlot(setupStreamId);
    }

    function test_pushSlot_InconsistentSlotsPerPacket() external {
        // Arrange
        streamManager.pushSlotsHarness(setupStreamId, 0, Constants.SLOTS_PER_PACKET, SlotState.FILLED);
        uint256 slotsLength = streamManager.getSlotsLengthHarness(setupStreamId, 0);
        assertEq(slotsLength, Constants.SLOTS_PER_PACKET, "Incorrect slots length");

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(IStreamManager.InconsistentSlotsPerPacket.selector, setupStreamId, 0, 101)
        );

        // Act
        streamManager.setSlotHarness(setupStreamId, 0, hex"00", 0, 0);
    }

    function test_createNewPacket_Success() external {
        // Arrange
        // we expect the packet number to be 1 since the first packet is being created in the test setup function
        uint64 expectedPacketNumber = 1;
        bytes32 committeePubKey = bytes32(uint256(1));

        // Assert
        vm.expectEmit(address(streamManager));
        emit IStreamManager.PacketCreated(setupStreamId, expectedPacketNumber);

        // Act
        vm.prank(address(registry));
        streamManager.createNewPacket(setupStreamId, COMMITTEE_ID_STREAM_1_PACKET_1, committeePubKey);

        // Assert
        Packet memory packet = streamManager.getPacket(setupStreamId, expectedPacketNumber);
        assertEq(packet.packetNumber, expectedPacketNumber, "packetNumber was not set correctly");
        assertEq(packet.committeePubKey, committeePubKey, "committeePubKey was not set correctly");
    }

    function test_setSecurityBond_Success() external {
        // Arrange
        uint64 streamId = 0;
        // More than 10 percent
        uint256 securityBond = BtcHelper.satoshiToWei(streamManager.getStreamById(streamId).denomination) * 11 / 100;

        // Assert
        assertNotEq(
            streamManager.getStreamById(streamId).securityBondValue,
            securityBond,
            "securityBond was initialized incorrectly"
        );

        // Act
        vm.prank(address(streamManager.owner()));
        streamManager.setSecurityBond(streamId, securityBond);

        // Assert
        assertEq(
            streamManager.getStreamById(streamId).securityBondValue, securityBond, "securityBond was not set correctly"
        );
    }

    function test_setSecurityBond_Revert_RequireGreaterThanZero() external {
        // Arrange
        uint64 streamId = 0;
        uint256 securityBond = 0;

        // Assert
        assertNotEq(
            streamManager.getStreamById(streamId).securityBondValue,
            securityBond,
            "securityBond was initialized incorrectly"
        );

        vm.prank(address(streamManager.owner()));

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IStreamManager.InvalidSecurityBondValue.selector, 0));

        // Act
        streamManager.setSecurityBond(streamId, securityBond);
    }

    function test_setSecurityBond_Revert_InvalidStreamId() external {
        // Arrange
        uint64 streamId = 10;
        uint256 securityBond = 1000;
        vm.prank(address(streamManager.owner()));

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IStreamManager.StreamNotFoundById.selector, streamId));

        // Act
        streamManager.setSecurityBond(streamId, securityBond);
    }

    function test_setSecurityBond_Revert_NotOwner() external {
        // Arrange
        uint64 streamId = 0;
        uint256 securityBond = 1000;

        // Assert
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, this));

        // Act
        streamManager.setSecurityBond(streamId, securityBond);
    }

    function test_setPeginConfirmations_Success() external {
        // Arrange
        uint64 streamId = 0;
        // Add 2 confirmations
        uint8 peginConfirmations = streamManager.getStreamById(streamId).peginConfirmations + 2;

        // Assert
        assertEq(
            streamManager.getStreamById(streamId).peginConfirmations,
            Constants.PEGIN_CONFIRMATION_DEFAULT,
            "Pegin confirmation should be default"
        );

        // Act
        vm.prank(address(streamManager.owner()));
        streamManager.setPeginConfirmations(streamId, peginConfirmations);

        // Assert
        assertEq(
            streamManager.getStreamById(streamId).peginConfirmations,
            peginConfirmations,
            "peginConfirmations was not set correctly"
        );
    }

    function test_setPeginConfirmations_Revert_RequireGreaterThanZero() external {
        // Arrange
        uint64 streamId = 0;
        vm.prank(address(streamManager.owner()));

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IStreamManager.InvalidPeginConfirmations.selector, 0));

        // Act
        streamManager.setPeginConfirmations(streamId, 0);
    }

    function test_setPeginConfirmations_Rever_InvalidStreamId() external {
        // Arrange
        uint64 streamId = 10;
        vm.prank(address(streamManager.owner()));

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IStreamManager.StreamNotFoundById.selector, streamId));

        // Act
        streamManager.setPeginConfirmations(streamId, 100);
    }

    function test_setPeginConfirmations_Revert_NotOwner() external {
        // Arrange
        uint64 streamId = 0;

        // Assert
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, this));

        // Act
        streamManager.setPeginConfirmations(streamId, 10);
    }

    function test_getCurrentPacketCommitteeId_Success() external {
        // Arrange
        setup_multipleRequestAndAcceptPeginFlows(Constants.SLOTS_PER_PACKET - 1, setupStreamId);

        // Act
        uint256 currentPacketCommitteeId = streamManager.getCurrentPacketCommitteeId(setupStreamId);

        // Assert
        assertEq(currentPacketCommitteeId, COMMITTEE_ID_STREAM_1_PACKET_0, "Current packet committee ID should match");
    }

    function test_getCurrentPacketCommitteeId_Success_NoCommitteeForCurrentPacket() external {
        // Arrange
        setup_multipleRequestAndAcceptPeginFlows(Constants.SLOTS_PER_PACKET, setupStreamId);

        // Act
        uint256 currentPacketCommitteeId = streamManager.getCurrentPacketCommitteeId(setupStreamId);

        // Assert
        assertEq(currentPacketCommitteeId, 0, "Current packet committee ID should be 0 when no committee exists");
    }
}
