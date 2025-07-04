// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {PegManager, BtcTxSPVProof} from "src/PegManager.sol";
import {ScriptUtils} from "script/helpers/ScriptUtils.sol";
import {HelperContract} from "test/helpers/HelperContract.sol";
import {Slot, Stream, SlotState, IStreamManager} from "src/interfaces/IStreamManager.sol";

contract RegisterOperatorTakeScript is ScriptUtils {
    PegManager pegManager;

    uint64 amount;
    Stream stream;
    IStreamManager streamManager;
    uint64 expectedPacketNumber;
    uint64 expectedSlotId;

    function setUp() internal {
        pegManager = PegManager(0x0165878A594ca255338adfa4d48449f69242Eb8F);
        amount = 100_000; // 0.001 BTC

        // Calculate expected slot and packet numbers
        streamManager = pegManager.streamManager();
        stream = streamManager.getStream(amount);
        expectedPacketNumber = stream.pegoutPacketPointer;
        expectedSlotId = stream.pegoutSlotPointer - 1; // At this point we already executed the peg out so we need to grab the previous slot
    }

    function run(bytes32 _pegoutSignatureHash) public {
        setUp();

        Slot memory slot = streamManager.getSlot(stream.streamId, expectedPacketNumber, expectedSlotId);
        if (slot.state != SlotState.LOCKED && slot.state != SlotState.ADVANCED) {
            revert("Slot should be marked as LOCKED or ADVANCED before triggering the operator take");
        }

        // Register operator take
        vm.startBroadcast(getDeployerKey());
        pegManager.triggerOperatorTake(_pegoutSignatureHash);
        vm.stopBroadcast();

        slot = streamManager.getSlot(stream.streamId, expectedPacketNumber, expectedSlotId);
        if (slot.state != SlotState.ADVANCED) {
            revert("Slot should be marked as ADVANCED after operator take triggered");
        }

        console.log("=== Operator Take triggered successfully ===");
        console.log("Stream, Slot, Packet");
        console.log(stream.streamId, expectedPacketNumber, expectedSlotId);
    }
}
