// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {console} from "forge-std/console.sol";
import {PegoutManager} from "src/PegoutManager.sol";
import {BtcTxSPVProof, StreamPosition} from "src/interfaces/IPegCommonTypes.sol";
import {ScriptUtils} from "script/helpers/ScriptUtils.sol";
import {ContractAddressManager} from "script/helpers/ContractAddressManager.sol";
import {Slot, SlotState, Stream, IStreamManager} from "src/interfaces/IStreamManager.sol";
import {BtcTransaction} from "src/interfaces/IBitcoinManager.sol";
import {BtcHelper} from "src/libraries/BtcHelper.sol";
import {ICommitteeRegistry} from "src/interfaces/ICommitteeRegistry.sol";
import {IMemberRegistry} from "src/interfaces/IMemberRegistry.sol";
import {IChallengeManager, ChallengeInfo} from "src/interfaces/IChallengeManager.sol";
import {IOperatorTakeManager} from "src/interfaces/IOperatorTakeManager.sol";
import {BridgeMock} from "test/helpers/BridgeMock.sol";

contract SkipOperatorWonScript is ScriptUtils, ContractAddressManager {
    PegoutManager pegoutManager;
    IChallengeManager challengeManager;
    IOperatorTakeManager operatorTakeManager;
    IStreamManager streamManager;

    uint64 amount;
    bytes operatorPubKey;
    bytes committeePubKey;
    bytes userPubKey;

    uint64 expectedStreamId;
    uint64 expectedPacketNumber;
    uint32 expectedSlotId;
    bytes32 expectedPegoutId;

    function setUp(bytes32 _acceptPeginTxid) internal {
        pegoutManager = PegoutManager(getPegoutManager());
        challengeManager = getChallengeManager();
        operatorTakeManager = getOperatorTakeManager();

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

        uint128 committeeId = streamManager.getCommitteeId(expectedStreamId, expectedPacketNumber);
        committeePubKey = registry.getCommitteePubKey(committeeId);

        expectedPegoutId = operatorTakeManager.getOperatorTakeInfo(_acceptPeginTxid).pegoutId;
    }

    function run(bytes32 _acceptPeginTxid) public {
        setUp(_acceptPeginTxid);

        // ADVANCE FUNDS
        BtcTransaction memory advanceFundsTx = createAdvanceFundsTx(userPubKey, amount, expectedPegoutId);
        BtcTxSPVProof memory advanceFundsSPV = createBtcTxSPVProof(advanceFundsTx);

        // Register advance funds
        vm.startBroadcast(getDeployerKey());
        operatorTakeManager.registerAdvanceFunds(_acceptPeginTxid, advanceFundsSPV);
        vm.stopBroadcast();

        // REIMBURSEMENT KICKOFF
        BtcTransaction memory kickoffTx = createReimbursementKickoffTx(committeePubKey, expectedSlotId);
        BtcTxSPVProof memory kickoffTxSPVProof = createBtcTxSPVProof(kickoffTx);
        bytes32 reimbursementKickoffTxid = getTxid(kickoffTx);

        // Register reimbursement kickoff
        vm.startBroadcast(getDeployerKey());
        operatorTakeManager.registerReimbursementKickoff(_acceptPeginTxid, kickoffTxSPVProof);
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
        BtcTransaction memory inputRevealedTx = createInputRevealedTx(challengeTxid, committeePubKey, operatorPubKey);
        BtcTxSPVProof memory inputRevealedSPVProof = createBtcTxSPVProof(inputRevealedTx);

        // Register input revealed
        vm.startBroadcast(getDeployerKey());
        challengeManager.registerInputRevealed(_acceptPeginTxid, inputRevealedSPVProof);
        vm.stopBroadcast();

        // ADVANCE BITCOIN BLOCKS past the skipOperatorWon threshold (local/mock only)
        _advanceBTCBlocksPastSkipThreshold(_acceptPeginTxid);

        // SKIP OPERATOR WON
        vm.startBroadcast(getDeployerKey());
        operatorTakeManager.skipOperatorWon(_acceptPeginTxid);
        vm.stopBroadcast();

        Slot memory slot = streamManager.getSlot(expectedStreamId, expectedPacketNumber, expectedSlotId);
        if (slot.state != SlotState.COMPLETED) {
            revert("Slot should be marked as COMPLETED after skip operator won");
        }

        console.log("=== Skip operator won registered successfully ===");
        console.log("Stream, Packet, Slot");
        console.log(expectedStreamId, expectedPacketNumber, expectedSlotId);
    }

    function _advanceBTCBlocksPastSkipThreshold(bytes32 _acceptPeginTxid) internal {
        ChallengeInfo memory info = challengeManager.getChallengeInfo(_acceptPeginTxid);
        Stream memory stream = streamManager.getStreamById(expectedStreamId);
        uint256 skipThreshold = uint256(stream.timelockSettings.opWonTimelock) + 2 * uint256(stream.pegoutConfirmations);
        int256 targetHeight = info.revealBtcBlockNumber + int256(skipThreshold);

        console.log("=== Advancing Bitcoin blocks ===");
        console.log("Reveal block number:");
        console.logInt(info.revealBtcBlockNumber);
        console.log("Skip threshold:");
        console.log(skipThreshold);
        console.log("Target height:");
        console.logInt(targetHeight);

        BridgeMock bridgeMock = BridgeMock(payable(address(getBridge())));
        vm.startBroadcast(getDeployerKey());
        bridgeMock.setBtcBlockchainBestChainHeight(targetHeight);
        vm.stopBroadcast();
    }
}
