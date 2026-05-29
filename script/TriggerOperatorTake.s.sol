// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {console} from "forge-std/console.sol";
import {IOperatorTakeManager} from "src/interfaces/IOperatorTakeManager.sol";
import {ScriptUtils} from "script/helpers/ScriptUtils.sol";
import {ContractAddressManager} from "script/helpers/ContractAddressManager.sol";
import {Slot, SlotState, IStreamManager} from "src/interfaces/IStreamManager.sol";
import {StreamPosition} from "src/interfaces/IPegCommonTypes.sol";

contract TriggerOperatorTakeScript is ScriptUtils, ContractAddressManager {
    IOperatorTakeManager operatorTakeManager;
    IStreamManager streamManager;
    uint64 amount;

    function setUp() internal {
        operatorTakeManager = getOperatorTakeManager();
        streamManager = IStreamManager(getStreamManager());
    }

    function run(bytes32 _acceptPeginTxid) public {
        setUp();

        console.log("=== Trigger Operator Take ===");
        StreamPosition memory streamPosition = streamManager.getStreamPosition(_acceptPeginTxid);
        Slot memory slot =
            streamManager.getSlot(streamPosition.streamId, streamPosition.packetNumber, streamPosition.slotId);
        if (slot.state != SlotState.LOCKED && slot.state != SlotState.ADVANCED) {
            revert("Slot should be marked as LOCKED or ADVANCED before triggering the operator take");
        }

        // Register operator take
        vm.startBroadcast(getDeployerKey());
        operatorTakeManager.triggerOperatorTake(_acceptPeginTxid);
        vm.stopBroadcast();

        slot = streamManager.getSlot(streamPosition.streamId, streamPosition.packetNumber, streamPosition.slotId);
        if (slot.state != SlotState.ADVANCED) {
            revert("Slot should be marked as ADVANCED after operator take triggered");
        }

        // console.log("=== Operator Take triggered successfully ===");
        // console.log("Stream, Packet, Slot");
        // console.log(streamPosition.streamId, streamPosition.packetNumber, streamPosition.slotId);
    }
}
