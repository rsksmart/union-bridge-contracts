// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {HelperContract} from "test/helpers/HelperContract.sol";
import {SlotState, Slot, Packet, IStreamManager} from "src/interfaces/IStreamManager.sol";

contract TestStreamManager is Test, HelperContract {
    function setUp() external {
        runTestDeployScript();
    }

    function test_getFirstFilledSlot_Success() external {
        // Arrange
        streamManager.setSlotHarness(0, 0, 0, SlotState.FILLED, hex"00", 0, 0);

        // Act
        (Slot memory slot,) = streamManager.getFirstFilledSlot(0);
        assertEq(uint64(slot.state), uint64(SlotState.FILLED), "Incorrect slot state");
    }

    function test_getFirstFilledSlot_NoFilledSlot() external {
        // Assert
        vm.expectRevert(abi.encodeWithSelector(IStreamManager.NoFilledSlot.selector, 0, 0));

        // Act
        streamManager.getFirstFilledSlot(0);
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

        // Act
        streamManager.createNewPacket(streamId, committeePubKey);

        // Assert
        Packet memory packet = streamManager.getPacket(streamId, expectedPacketNumber);

        // Assert
        assertEq(packet.packetNumber, expectedPacketNumber, "packetNumber was not set correctly");
        assertEq(packet.committeePubKey, committeePubKey, "committeePubKey was not set correctly");
    }
}
