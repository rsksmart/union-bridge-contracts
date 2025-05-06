// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {HelperContract} from "test/helpers/HelperContract.sol";
import {SlotState, Slot, IStreamManager} from "src/interfaces/IStreamManager.sol";

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
}
