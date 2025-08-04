// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {console} from "forge-std/console.sol";
import {PegManager} from "src/PegManager.sol";
import {ScriptUtils} from "script/helpers/ScriptUtils.sol";
import {Slot, SlotState, IStreamManager} from "src/interfaces/IStreamManager.sol";

contract BlockSlotScript is ScriptUtils {
    PegManager pegManager;
    IStreamManager streamManager;

    function setUp() internal {
        // ====== Arguments ======
        pegManager = PegManager(0x0165878A594ca255338adfa4d48449f69242Eb8F);
        streamManager = IStreamManager(pegManager.streamManager());
    }

    function run(uint64 _streamId, uint64 _packetNumber, uint64 _slotId) public {
        setUp();

        console.log("=== Block Reserved Slot ===");
        console.log("Stream ID:", _streamId);
        console.log("Packet Number:", _packetNumber);
        console.log("Slot ID:", _slotId);

        // Check current slot state
        Slot memory slot = streamManager.getSlot(_streamId, _packetNumber, _slotId);
        console.log("Current slot state:", uint256(slot.state));

        if (slot.state != SlotState.RESERVED) {
            revert("Slot is not in RESERVED state - cannot block");
        }

        // Block the slot
        vm.startBroadcast(getDeployerKey());
        streamManager.blockSlot(_streamId, _packetNumber, _slotId);
        vm.stopBroadcast();

        // Verify slot was blocked
        slot = streamManager.getSlot(_streamId, _packetNumber, _slotId);
        if (slot.state != SlotState.BLOCKED) {
            revert("Slot was not blocked successfully");
        }

        console.log("=== Slot blocked successfully ===");
        console.log("New slot state:", uint256(slot.state));
    }
}
