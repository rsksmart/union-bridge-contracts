// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {console} from "forge-std/console.sol";
import {PegoutManager} from "src/PegoutManager.sol";
import {ScriptUtils} from "script/helpers/ScriptUtils.sol";
import {ContractAddressManager} from "script/helpers/ContractAddressManager.sol";
import {Slot, SlotState, IStreamManager} from "src/interfaces/IStreamManager.sol";
import {StreamPosition} from "src/interfaces/IPegCommonTypes.sol";

contract TriggerOperatorTakeScript is ScriptUtils, ContractAddressManager {
    PegoutManager pegoutManager;
    IStreamManager streamManager;
    uint64 amount;

    function setUp() internal {
        pegoutManager = PegoutManager(getPegoutManager());
        streamManager = pegoutManager.streamManager();
    }

    function run(bytes32 _pegoutTxId) public {
        setUp();

        console.log("=== Trigger Operator Take ===");
        bytes32 acceptPeginTxid = pegoutManager.getAcceptPeginTxid(_pegoutTxId);
        StreamPosition memory streamPosition = streamManager.getStreamPosition(acceptPeginTxid);
        Slot memory slot =
            streamManager.getSlot(streamPosition.streamId, streamPosition.packetNumber, streamPosition.slotId);
        if (slot.state != SlotState.LOCKED && slot.state != SlotState.ADVANCED) {
            revert("Slot should be marked as LOCKED or ADVANCED before triggering the operator take");
        }

        // Register operator take
        vm.startBroadcast(getDeployerKey());
        pegoutManager.triggerOperatorTake(_pegoutTxId);
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
