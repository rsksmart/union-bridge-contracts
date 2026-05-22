// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {console} from "forge-std/console.sol";
import {BtcTxSPVProof, StreamPosition} from "src/interfaces/IPegCommonTypes.sol";
import {ScriptUtils} from "script/helpers/ScriptUtils.sol";
import {ContractAddressManager} from "script/helpers/ContractAddressManager.sol";
import {Slot, SlotState, IStreamManager} from "src/interfaces/IStreamManager.sol";
import {BtcTransaction} from "src/interfaces/IBitcoinManager.sol";
import {BtcHelper} from "src/libraries/BtcHelper.sol";
import {ICommitteeRegistry} from "src/interfaces/ICommitteeRegistry.sol";
import {IMemberRegistry} from "src/interfaces/IMemberRegistry.sol";
import {IOperatorTakeManager} from "src/interfaces/IOperatorTakeManager.sol";

contract RegisterOperatorTakeScript is ScriptUtils, ContractAddressManager {
    IOperatorTakeManager operatorTakeManager;
    IStreamManager streamManager;

    uint64 amount;
    bytes operatorDisputePubKey;

    uint64 expectedStreamId;
    uint64 expectedPacketNumber;
    uint32 expectedSlotId;

    function setUp(bytes32 _acceptPeginTxid) internal {
        operatorTakeManager = getOperatorTakeManager();

        ICommitteeRegistry committeeRegistry = getCommitteeRegistry();
        IMemberRegistry memberRegistry = committeeRegistry.memberRegistry();

        operatorDisputePubKey =
            BtcHelper.compactPubKeyToBytes(memberRegistry.getMemberDisputePubKey(getDeployerAddress()));

        amount = 100_000; // 0.001 BTC

        streamManager = IStreamManager(getStreamManager());
        StreamPosition memory streamPosition = streamManager.getStreamPosition(_acceptPeginTxid);
        expectedStreamId = streamPosition.streamId;
        expectedPacketNumber = streamPosition.packetNumber;
        expectedSlotId = uint32(streamPosition.slotId);
    }

    function run(bytes32 _acceptPeginTxid, bytes32 _reimbursementKickoffTxid) public {
        setUp(_acceptPeginTxid);

        console.log("=== Register Operator Take ===");

        // OPERATOR TAKE
        BtcTransaction memory takeTx =
            createOperatorTakeTx(_acceptPeginTxid, _reimbursementKickoffTxid, operatorDisputePubKey, amount);
        BtcTxSPVProof memory takeTxSPVProof = createBtcTxSPVProof(takeTx);

        // Register operator take
        vm.startBroadcast(getDeployerKey());
        operatorTakeManager.registerOperatorTake(takeTxSPVProof);
        vm.stopBroadcast();

        Slot memory slot = streamManager.getSlot(expectedStreamId, expectedPacketNumber, expectedSlotId);
        if (slot.state != SlotState.COMPLETED) {
            revert("Slot should be marked as COMPLETED after operator take peg-out registration");
        }

        console.log("=== Operator take Pegout registered successfully ===");
        console.log("Stream, Packet, Slot");
        console.log(expectedStreamId, expectedPacketNumber, expectedSlotId);
    }
}
