// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {console} from "forge-std/console.sol";
import {BtcTxSPVProof, StreamPosition} from "src/interfaces/IPegCommonTypes.sol";
import {ScriptUtils} from "script/helpers/ScriptUtils.sol";
import {ContractAddressManager} from "script/helpers/ContractAddressManager.sol";
import {IStreamManager} from "src/interfaces/IStreamManager.sol";
import {BtcTransaction} from "src/interfaces/IBitcoinManager.sol";
import {IChallengeManager} from "src/interfaces/IChallengeManager.sol";
import {ICommitteeRegistry} from "src/interfaces/ICommitteeRegistry.sol";
import {IMemberRegistry} from "src/interfaces/IMemberRegistry.sol";
import {BtcHelper} from "src/libraries/BtcHelper.sol";

contract RegisterInputRevealedScript is ScriptUtils, ContractAddressManager {
    IChallengeManager challengeManager;
    IStreamManager streamManager;
    ICommitteeRegistry committeeRegistry;

    bytes committeeTakePubKey;
    bytes committeeDisputePubKey;
    bytes operatorDisputePubKey;
    uint32 expectedSlotId;
    bytes32 challengeTxid;

    function setUp(bytes32 _acceptPeginTxid) internal {
        challengeManager = getChallengeManager();
        streamManager = IStreamManager(getStreamManager());
        committeeRegistry = getCommitteeRegistry();

        StreamPosition memory streamPosition = streamManager.getStreamPosition(_acceptPeginTxid);
        expectedSlotId = uint32(streamPosition.slotId);

        uint128 committeeId = streamManager.getCommitteeId(streamPosition.streamId, streamPosition.packetNumber);
        committeeTakePubKey = committeeRegistry.getCommitteeTakePubKey(committeeId);
        committeeDisputePubKey = committeeRegistry.getCommitteeDisputePubKey(committeeId);

        IMemberRegistry memberRegistry = committeeRegistry.memberRegistry();
        operatorDisputePubKey =
            BtcHelper.compactPubKeyToBytes(memberRegistry.getMemberDisputePubKey(getDeployerAddress()));

        bytes32 reimbursementKickoffTxid = getTxid(createReimbursementKickoffTx(committeeTakePubKey, expectedSlotId));
        challengeTxid = getTxid(createChallengeTx(reimbursementKickoffTxid, committeeDisputePubKey));
    }

    function run(bytes32 _acceptPeginTxid) public {
        setUp(_acceptPeginTxid);

        console.log("=== Register Input Revealed ===");

        BtcTransaction memory inputRevealedTx =
            createInputRevealedTx(challengeTxid, committeeDisputePubKey, operatorDisputePubKey);
        BtcTxSPVProof memory inputRevealedSPVProof = createBtcTxSPVProof(inputRevealedTx);

        vm.startBroadcast(getDeployerKey());
        challengeManager.registerInputRevealed(_acceptPeginTxid, inputRevealedSPVProof);
        vm.stopBroadcast();

        console.log("=== Input Revealed registered successfully ===");
    }
}
