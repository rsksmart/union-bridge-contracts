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
import {IChallengeManager} from "src/ChallengeManager.sol";

contract RegisterOperatorTakeScript is ScriptUtils, ContractAddressManager {
    PegoutManager pegoutManager;
    IChallengeManager challengeManager;
    IStreamManager streamManager;

    uint64 amount;
    bytes operatorPubKey;
    bytes32 acceptPeginTxid;
    bytes committeePubKey;
    bytes userPubKey;

    uint64 expectedStreamId;
    uint64 expectedPacketNumber;
    uint64 expectedSlotId;

    function setUp(bytes32 _acceptPeginTxid) internal {
        pegoutManager = PegoutManager(getPegoutManager());
        challengeManager = getChallengeManager();

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
        expectedSlotId = streamPosition.slotId;

        Packet memory packet = streamManager.getPacket(expectedStreamId, expectedPacketNumber);
        committeePubKey = packet.committeePubKey;
    }

    function run(bytes32 _acceptPeginTxid, bytes32 _pegoutId) public {
        setUp(_acceptPeginTxid);

        // ADVANCE FUNDS
        BtcTransaction memory advanceFundsTx = createAdvanceFundsTx(userPubKey, amount, _pegoutId);
        BtcTxSPVProof memory advanceFundsSPV = createBtcTxSPVProof(advanceFundsTx);

        // Register advance funds
        vm.startBroadcast(getDeployerKey());
        pegoutManager.registerAdvanceFunds(_acceptPeginTxid, advanceFundsSPV);
        vm.stopBroadcast();

        // REIMBURSEMENT KICKOFF
        BtcTransaction memory kickoffTx = createReimbursementKickoffTx(committeePubKey, uint32(expectedSlotId));
        BtcTxSPVProof memory kickoffTxSPVProof = createBtcTxSPVProof(kickoffTx);
        bytes32 reimbursementKickoffTxid = getTxid(kickoffTx);

        // Register reimbursement kickoff
        vm.startBroadcast(getDeployerKey());
        pegoutManager.registerReimbursementKickoff(_acceptPeginTxid, kickoffTxSPVProof);
        vm.stopBroadcast();

        // CHALLENGE
        BtcTransaction memory challengeTx = createChallengeTx(reimbursementKickoffTxid, committeePubKey);
        bytes32 challengeTxid = getTxid(challengeTx);
        BtcTxSPVProof memory challengeSPVProof = createBtcTxSPVProof(challengeTx);

        // Register challenge
        vm.startBroadcast(getDeployerKey());
        challengeManager.registerChallenge(_acceptPeginTxid, challengeSPVProof);
        vm.stopBroadcast();

        // INPUT REVEALED
        BtcTransaction memory inputRevealedTx = createRevealTx(challengeTxid, committeePubKey);
        bytes32 inputRevealedTxid = getTxid(inputRevealedTx);
        BtcTxSPVProof memory inputRevealedSPVProof = createBtcTxSPVProof(inputRevealedTx);

        // Register input revealed
        vm.startBroadcast(getDeployerKey());
        challengeManager.registerInputRevealed(_acceptPeginTxid, inputRevealedSPVProof);
        vm.stopBroadcast();

        // OPERATOR WON
        BtcTransaction memory wonTx = createOperatorWonTx(_acceptPeginTxid, inputRevealedTxid, operatorPubKey, amount);
        BtcTxSPVProof memory wonTxSPVProof = createBtcTxSPVProof(wonTx);

        // Register operator won
        vm.startBroadcast(getDeployerKey());
        pegoutManager.registerOperatorWon(wonTxSPVProof);
        vm.stopBroadcast();

        Slot memory slot = streamManager.getSlot(expectedStreamId, expectedPacketNumber, expectedSlotId);
        if (slot.state != SlotState.COMPLETED) {
            revert("Slot should be marked as COMPLETED after operator won peg-out registration");
        }

        console.log("=== Operator take Pegout registered successfully ===");
        console.log("Stream, Packet, Slot");
        console.log(expectedStreamId, expectedPacketNumber, expectedSlotId);
    }
}
