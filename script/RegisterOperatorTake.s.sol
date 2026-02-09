// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {console} from "forge-std/console.sol";
import {PegoutManager} from "src/PegoutManager.sol";
import {BtcTxSPVProof, StreamPosition} from "src/interfaces/IPegCommonTypes.sol";
import {ScriptUtils} from "script/helpers/ScriptUtils.sol";
import {ContractAddressManager} from "script/helpers/ContractAddressManager.sol";
import {Slot, SlotState, IStreamManager, Packet} from "src/interfaces/IStreamManager.sol";
import {BtcTransaction} from "src/interfaces/IBitcoinManager.sol";
import {BtcHelper} from "src/libraries/BtcHelper.sol";
import {ICommitteeRegistry} from "src/interfaces/ICommitteeRegistry.sol";
import {IMemberRegistry} from "src/interfaces/IMemberRegistry.sol";

contract RegisterOperatorTakeScript is ScriptUtils, ContractAddressManager {
    PegoutManager pegoutManager;

    uint64 amount;
    bytes operatorPubKey;
    bytes32 acceptPeginTxid;
    bytes committeePubKey;
    bytes userPubKey;

    IStreamManager streamManager;
    uint64 expectedStreamId;
    uint64 expectedPacketNumber;
    uint32 expectedSlotId;
    bytes32 expectedPegoutId;

    function setUp(bytes32 _acceptPeginTxid) internal {
        pegoutManager = PegoutManager(getPegoutManager());

        ICommitteeRegistry registry = getCommitteeRegistry();
        IMemberRegistry memberRegistry = registry.memberRegistry();

        bytes32 operatorXOnlyPubKey = memberRegistry.getMemberPublicKeys(getDeployerAddress()).covenantPubKey;
        operatorPubKey = BtcHelper.pubKeyXonlyToCompact(operatorXOnlyPubKey);
        userPubKey = hex"02d56ad001b55eabf431e602599fcc0d7ed9d676ac93c2be11d0de6e25dd598d8b";
        amount = 100_000; // 0.001 BTC

        // Calculate expected slot and packet numbers
        streamManager = IStreamManager(getStreamManager());
        StreamPosition memory streamPosition = streamManager.getStreamPosition(_acceptPeginTxid);
        expectedStreamId = streamPosition.streamId;
        expectedPacketNumber = streamPosition.packetNumber;
        expectedSlotId = uint32(streamPosition.slotId);

        Packet memory packet = streamManager.getPacket(expectedStreamId, expectedPacketNumber);
        committeePubKey = packet.committeePubKey;

        expectedPegoutId = pegoutManager.getPegoutTempInfo(_acceptPeginTxid).pegoutId;
    }

    function run(bytes32 _acceptPeginTxid) public {
        setUp(_acceptPeginTxid);

        // ADVANCE FUNDS
        BtcTransaction memory advanceFundsTx = createAdvanceFundsTx(userPubKey, amount, expectedPegoutId);
        BtcTxSPVProof memory advanceFundsSPV = createBtcTxSPVProof(advanceFundsTx);

        // Register advance funds
        vm.startBroadcast(getDeployerKey());
        pegoutManager.registerAdvanceFunds(_acceptPeginTxid, advanceFundsSPV);
        vm.stopBroadcast();

        // REIMBURSEMENT KICKOFF
        BtcTransaction memory kickoffTx = createReimbursementKickoffTx(committeePubKey, expectedSlotId);
        BtcTxSPVProof memory kickoffTxSPVProof = createBtcTxSPVProof(kickoffTx);
        bytes32 reimbursementKickoffTxid = getTxid(kickoffTx);

        // Register reimbursement kickoff
        vm.startBroadcast(getDeployerKey());
        pegoutManager.registerReimbursementKickoff(_acceptPeginTxid, kickoffTxSPVProof);
        vm.stopBroadcast();

        // OPERATOR TAKE
        BtcTransaction memory takeTx =
            createOperatorTakeTx(_acceptPeginTxid, reimbursementKickoffTxid, operatorPubKey, amount);
        BtcTxSPVProof memory takeTxSPVProof = createBtcTxSPVProof(takeTx);

        // Register operator take
        vm.startBroadcast(getDeployerKey());
        pegoutManager.registerOperatorTake(takeTxSPVProof);
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
