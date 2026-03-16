// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {console} from "forge-std/console.sol";
import {StreamPosition} from "src/interfaces/IPegCommonTypes.sol";
import {ScriptUtils} from "script/helpers/ScriptUtils.sol";
import {ContractAddressManager} from "script/helpers/ContractAddressManager.sol";
import {Slot, SlotState, IStreamManager} from "src/interfaces/IStreamManager.sol";
import {IOperatorTakeManager} from "src/interfaces/IOperatorTakeManager.sol";

contract SkipOperatorTakeScript is ScriptUtils, ContractAddressManager {
    IOperatorTakeManager operatorTakeManager;
    IStreamManager streamManager;

    uint64 expectedStreamId;
    uint64 expectedPacketNumber;
    uint32 expectedSlotId;

    function setUp(bytes32 _acceptPeginTxid) internal {
        operatorTakeManager = getOperatorTakeManager();
        streamManager = IStreamManager(getStreamManager());

        StreamPosition memory streamPosition = streamManager.getStreamPosition(_acceptPeginTxid);
        expectedStreamId = streamPosition.streamId;
        expectedPacketNumber = streamPosition.packetNumber;
        expectedSlotId = uint32(streamPosition.slotId);
    }

    function run(bytes32 _acceptPeginTxid) public {
        setUp(_acceptPeginTxid);

        console.log("=== Skip Operator Take ===");

        // SKIP OPERATOR TAKE
        vm.startBroadcast(getDeployerKey());
        operatorTakeManager.skipOperatorTake(_acceptPeginTxid);
        vm.stopBroadcast();

        Slot memory slot = streamManager.getSlot(expectedStreamId, expectedPacketNumber, expectedSlotId);
        if (slot.state != SlotState.COMPLETED) {
            revert("Slot should be marked as COMPLETED after skip operator take");
        }

        console.log("=== Skip operator take registered successfully ===");
        console.log("Stream, Packet, Slot");
        console.log(expectedStreamId, expectedPacketNumber, expectedSlotId);
    }
}
