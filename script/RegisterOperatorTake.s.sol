// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {console} from "forge-std/console.sol";
import {PegManager, BtcTxSPVProof, StreamPosition} from "src/PegManager.sol";
import {ScriptUtils} from "script/helpers/ScriptUtils.sol";
import {Slot, SlotState, IStreamManager} from "src/interfaces/IStreamManager.sol";
import {BtcTransaction} from "src/interfaces/IBitcoinManager.sol";
import {ICommitteeRegistry} from "src/interfaces/ICommitteeRegistry.sol";
import {IMemberRegistry} from "src/interfaces/IMemberRegistry.sol";

contract RegisterOperatorTakeScript is ScriptUtils {
    PegManager pegManager;

    uint64 amount;
    bytes operatorPubKey;
    bytes32 acceptPeginTxid;

    IStreamManager streamManager;
    uint64 expectedStreamId;
    uint64 expectedPacketNumber;
    uint64 expectedSlotId;

    function setUp(bytes32 _acceptPeginTxid) internal {
        pegManager = PegManager(0x2279B7A0a67DB372996a5FaB50D91eAA73d2eBe6);

        ICommitteeRegistry registry = ICommitteeRegistry(pegManager.committeeRegistry());
        IMemberRegistry memberRegistry = registry.memberRegistry();
        bytes32 operatorXOnlyPubKey = memberRegistry.getMemberPublicKeys(getDeployerAddress()).covenantPubKey;
        operatorPubKey = abi.encodePacked(bytes1(0x02), operatorXOnlyPubKey);
        amount = 100_000; // 0.001 BTC

        // Calculate expected slot and packet numbers
        streamManager = pegManager.streamManager();
        StreamPosition memory streamPosition = pegManager.getStreamPosition(_acceptPeginTxid);
        expectedStreamId = streamPosition.streamId;
        expectedPacketNumber = streamPosition.packetNumber;
        expectedSlotId = streamPosition.slotId;
    }

    function run(bytes32 _acceptPeginTxid) public {
        setUp(_acceptPeginTxid);

        BtcTransaction memory pegoutTx = createPegoutTx(_acceptPeginTxid, operatorPubKey, amount);
        BtcTxSPVProof memory pegoutTxSPVProof = createBtcTxSPVProof(pegoutTx);

        // Register operator take
        vm.startBroadcast(getDeployerKey());
        pegManager.registerOperatorTake(pegoutTxSPVProof);
        vm.stopBroadcast();

        Slot memory slot = streamManager.getSlot(expectedStreamId, expectedPacketNumber, expectedSlotId);
        if (slot.state != SlotState.COMPLETED) {
            revert("Slot should be marked as COMPLETED after operator take peg-out registration");
        }

        console.log("=== Operator take Pegout registered successfully ===");
        console.log("Stream, Slot, Packet");
        console.log(expectedStreamId, expectedPacketNumber, expectedSlotId);
    }
}
