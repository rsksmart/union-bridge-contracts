// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {console} from "forge-std/console.sol";
import {PegoutManager} from "src/PegoutManager.sol";
import {ScriptUtils} from "script/helpers/ScriptUtils.sol";
import {ContractAddressManager} from "script/helpers/ContractAddressManager.sol";
import {Slot, Stream, SlotState, IStreamManager} from "src/interfaces/IStreamManager.sol";

contract TriggerOperatorTakeScript is ScriptUtils, ContractAddressManager {
    PegoutManager pegoutManager;

    uint64 amount;
    Stream stream;
    IStreamManager streamManager;
    uint64 expectedPacketNumber;
    uint64 expectedSlotId;

    function setUp() internal {
        pegoutManager = PegoutManager(getPegoutManager());
        amount = 100_000; // 0.001 BTC

        // Calculate expected slot and packet numbers
        streamManager = pegoutManager.streamManager();
        stream = streamManager.getStream(amount);
        expectedPacketNumber = stream.pegoutPacketPointer;
        expectedSlotId = stream.pegoutSlotPointer; // At this point we already executed the peg out
    }

    function run(bytes32 _pegoutSignatureHash) public {
        setUp();

        Slot memory slot = streamManager.getSlot(stream.streamId, expectedPacketNumber, expectedSlotId);
        if (slot.state != SlotState.LOCKED && slot.state != SlotState.ADVANCED) {
            revert("Slot should be marked as LOCKED or ADVANCED before triggering the operator take");
        }

        // Register operator take
        vm.startBroadcast(getDeployerKey());
        pegoutManager.triggerOperatorTake(_pegoutSignatureHash);
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
