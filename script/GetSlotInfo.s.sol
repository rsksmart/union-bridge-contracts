// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {console} from "forge-std/console.sol";
import {PegManager} from "src/PegManager.sol";
import {ScriptUtils} from "script/helpers/ScriptUtils.sol";
import {Slot, SlotState, IStreamManager} from "src/interfaces/IStreamManager.sol";

contract GetSlotInfoScript is ScriptUtils {
    PegManager pegManager;
    IStreamManager streamManager;

    function setUp() internal {
        pegManager = PegManager(0x0165878A594ca255338adfa4d48449f69242Eb8F);
        streamManager = IStreamManager(pegManager.streamManager());
    }

    function run(uint64 _streamId, uint64 _packetNumber, uint64 _slotId) public {
        setUp();

        console.log("=== Slot Information ===");
        console.log("Stream ID:", _streamId);
        console.log("Packet Number:", _packetNumber);
        console.log("Slot ID:", _slotId);

        vm.startBroadcast(getDeployerKey());
        Slot memory slot = streamManager.getSlot(_streamId, _packetNumber, _slotId);
        vm.stopBroadcast();

        console.log("Slot State:", uint256(slot.state));
        string memory stateString = "";
        if (slot.state == SlotState.RESERVED) {
            stateString = "RESERVED";
        } else if (slot.state == SlotState.FILLED) {
            stateString = "FILLED";
        } else if (slot.state == SlotState.LOCKED) {
            stateString = "LOCKED";
        } else if (slot.state == SlotState.ADVANCED) {
            stateString = "ADVANCED";
        } else if (slot.state == SlotState.COMPLETED) {
            stateString = "COMPLETED";
        } else if (slot.state == SlotState.BLOCKED) {
            stateString = "BLOCKED";
        }
        console.log("State Name:", stateString);

        console.log("Accept Pegin Tx:");
        console.logBytes32(slot.acceptPeginTx);
        console.log("Accept Pegin Amount:", slot.acceptPeginAmount);
        console.log("Script Pub Key Length:", slot.scriptPubKey.length);
        console.log("Take0 Tx:");
        console.logBytes32(slot.take0Tx);
        console.log("Take1 Tx:");
        console.logBytes32(slot.take1Tx);
    }
}
