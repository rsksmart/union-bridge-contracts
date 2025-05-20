// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {HelperContract} from "test/helpers/HelperContract.sol";
import {SlotState, Slot, Packet, IStreamManager} from "src/interfaces/IStreamManager.sol";
import {Constants} from "src/libraries/Constants.sol";
import {BtcHelper} from "src/libraries/BtcHelper.sol";

contract TestStreamManager is Test, HelperContract {
    function setUp() external {
        runTestDeployScript();
    }

    function test_lockSlot_Success() external {
        // Arrange
        streamManager.setSlotHarness(0, 0, hex"00", 0, 0);

        vm.prank(address(pm));
        // Act
        (Slot memory slot,) = streamManager.lockSlot(0);
        assertEq(uint64(slot.state), uint64(SlotState.LOCKED), "Incorrect slot state");
    }

    function test_lockSlot_NonExistentSlot() external {
        // Assert
        vm.expectRevert(abi.encodeWithSelector(IStreamManager.NonExistentSlot.selector, 0, 0, 0));

        vm.prank(address(pm));
        // Act
        streamManager.lockSlot(0);
    }

    function test_lockSlot_InconsistentPegoutPointer() external {
        streamManager.pushSlots(0, 0, Constants.SLOTS_PER_PACKET + 1, SlotState.FILLED);
        streamManager.setPegoutPointers(0, 0, Constants.SLOTS_PER_PACKET);

        uint256 slotsLength = streamManager.getSlotsLength(0, 0);
        assertEq(slotsLength, Constants.SLOTS_PER_PACKET + 1, "Incorrect slots length");

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IStreamManager.InconsistentPegoutPointer.selector, 0, 0, 101));
        vm.prank(address(pm));
        streamManager.lockSlot(0);
    }

    function test_lockSlot_NoFilledSlot() external {
        streamManager.pushSlots(0, 0, 1, SlotState.LOCKED);

        uint256 slotsLength = streamManager.getSlotsLength(0, 0);
        assertEq(slotsLength, 1, "Incorrect slots length");

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IStreamManager.NoFilledSlot.selector, 0, 0, 0));
        vm.prank(address(pm));
        streamManager.lockSlot(0);
    }

    function test_pushSlot_InconsistentSlotsPerPacket() external {
        streamManager.pushSlots(0, 0, Constants.SLOTS_PER_PACKET, SlotState.FILLED);

        uint256 slotsLength = streamManager.getSlotsLength(0, 0);
        assertEq(slotsLength, Constants.SLOTS_PER_PACKET, "Incorrect slots length");

        vm.expectRevert(abi.encodeWithSelector(IStreamManager.InconsistentSlotsPerPacket.selector, 0, 0, 101));
        streamManager.setSlotHarness(0, 0, hex"00", 0, 0);
    }

    function test_createNewPacket_Success() external {
        // Arrange
        uint64 streamId = 0;
        // we expect the packet number to be 1 since the first packet is being created in the setup function
        uint64 expectedPacketNumber = 1;
        bytes32 committeePubKey = bytes32(uint256(1));

        // Assert
        vm.expectEmit(address(streamManager));

        emit IStreamManager.PacketCreated(streamId, expectedPacketNumber);

        vm.prank(address(pm));
        // Act
        streamManager.createNewPacket(streamId, committeePubKey);

        // Assert
        Packet memory packet = streamManager.getPacket(streamId, expectedPacketNumber);

        // Assert
        assertEq(packet.packetNumber, expectedPacketNumber, "packetNumber was not set correctly");
        assertEq(packet.committeePubKey, committeePubKey, "committeePubKey was not set correctly");
    }

    function test_setSecurityBond_Success() external {
        // Arrange
        uint64 streamId = 0;
        // More than 10 percent
        uint256 securityBond = BtcHelper.satoshiToWei(streamManager.getStreamById(streamId).denomination) * 11 / 100;

        assertNotEq(
            streamManager.getStreamById(streamId).securityBondValue,
            securityBond,
            "securityBond was initialized incorrectly"
        );

        vm.prank(address(streamManager.owner()));
        // Act
        streamManager.setSecurityBond(streamId, securityBond);

        // Assert
        assertEq(
            streamManager.getStreamById(streamId).securityBondValue, securityBond, "securityBond was not set correctly"
        );
    }

    function test_setSecurityBond_RequireGreaterThanZero() external {
        // Arrange
        uint64 streamId = 0;
        uint256 securityBond = 0;

        assertNotEq(
            streamManager.getStreamById(streamId).securityBondValue,
            securityBond,
            "securityBond was initialized incorrectly"
        );

        vm.prank(address(streamManager.owner()));

        vm.expectRevert(bytes("Security bond value must be greater than 0"));
        // Act
        streamManager.setSecurityBond(streamId, securityBond);
    }

    function test_setSecurityBond_InvalidStreamId() external {
        // Arrange
        uint64 streamId = 10;
        uint256 securityBond = 1000;

        vm.prank(address(streamManager.owner()));

        vm.expectRevert(bytes("Stream does not exist"));
        // Act
        streamManager.setSecurityBond(streamId, securityBond);
    }

    function test_setPeginConfirmations_Success() external {
        uint64 streamId = 0;
        // Add 2 confirmations
        uint8 peginConfirmations = streamManager.getStreamById(streamId).peginConfirmations + 2;

        assertNotEq(
            streamManager.getStreamById(streamId).peginConfirmations,
            peginConfirmations,
            "Old and new peginConfirmations should not match"
        );

        vm.prank(address(streamManager.owner()));
        streamManager.setPeginConfirmations(streamId, peginConfirmations);

        // Assert
        assertEq(
            streamManager.getStreamById(streamId).peginConfirmations,
            peginConfirmations,
            "peginConfirmations was not set correctly"
        );
    }

    function test_setPeginConfirmations_RequireGreaterThanZero() external {
        // Arrange
        uint64 streamId = 0;

        vm.prank(address(streamManager.owner()));
        vm.expectRevert(bytes("Confirmations must be greater than 0"));
        // Act
        streamManager.setPeginConfirmations(streamId, 0);
    }

    function test_setPeginConfirmations_InvalidStreamId() external {
        // Arrange
        uint64 streamId = 10;

        vm.prank(address(streamManager.owner()));
        vm.expectRevert(bytes("Stream does not exist"));
        // Act
        streamManager.setPeginConfirmations(streamId, 100);
    }
}
