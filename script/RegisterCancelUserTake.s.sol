// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {console} from "forge-std/console.sol";
import {IOperatorTakeManager} from "src/interfaces/IOperatorTakeManager.sol";
import {BtcTxSPVProof, StreamPosition} from "src/interfaces/IPegCommonTypes.sol";
import {ScriptUtils} from "script/helpers/ScriptUtils.sol";
import {ContractAddressManager} from "script/helpers/ContractAddressManager.sol";
import {Slot, SlotState, IStreamManager} from "src/interfaces/IStreamManager.sol";
import {BtcTransaction} from "src/interfaces/IBitcoinManager.sol";
import {BtcHelper} from "src/libraries/BtcHelper.sol";
import {ICommitteeRegistry} from "src/interfaces/ICommitteeRegistry.sol";
import {IMemberRegistry} from "src/interfaces/IMemberRegistry.sol";

contract RegisterCancelUserTakeScript is ScriptUtils, ContractAddressManager {
    IOperatorTakeManager operatorTakeManager;

    bytes operatorPubKey;
    bytes32 acceptPeginTxid;

    IStreamManager streamManager;
    uint64 expectedStreamId;
    uint64 expectedPacketNumber;
    uint64 expectedSlotId;

    function setUp(bytes32 _acceptPeginTxid) internal {
        operatorTakeManager = IOperatorTakeManager(getOperatorTakeManager());

        ICommitteeRegistry registry = getCommitteeRegistry();
        IMemberRegistry memberRegistry = registry.memberRegistry();

        operatorPubKey = BtcHelper.compactPubKeyToBytes(memberRegistry.getMemberDisputePubKey(getDeployerAddress()));

        // Calculate expected slot and packet numbers
        streamManager = IStreamManager(getStreamManager());
        StreamPosition memory streamPosition = streamManager.getStreamPosition(_acceptPeginTxid);
        expectedStreamId = streamPosition.streamId;
        expectedPacketNumber = streamPosition.packetNumber;
        expectedSlotId = streamPosition.slotId;
    }

    function run(bytes32 _acceptPeginTxid) public {
        setUp(_acceptPeginTxid);

        // CANCEL USER TAKE
        BtcTransaction memory cancelUserTakeTx = createCancelUserTakeTx(_acceptPeginTxid, operatorPubKey);
        BtcTxSPVProof memory cancelUserTakeSPV = createBtcTxSPVProof(cancelUserTakeTx);

        // Register cancel user take
        vm.startBroadcast(getDeployerKey());
        operatorTakeManager.registerCancelUserTake(cancelUserTakeSPV);
        vm.stopBroadcast();

        Slot memory slot = streamManager.getSlot(expectedStreamId, expectedPacketNumber, expectedSlotId);
        if (slot.state != SlotState.ADVANCED) {
            revert("Slot should still be marked as ADVANCED after cancel user take flow registration");
        }

        console.log("=== Cancel user take flow registered successfully ===");
        console.log("Stream, Packet, Slot");
        console.log(expectedStreamId, expectedPacketNumber, expectedSlotId);
    }
}
