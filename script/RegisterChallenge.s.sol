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

contract RegisterChallengeScript is ScriptUtils, ContractAddressManager {
    IChallengeManager challengeManager;
    IStreamManager streamManager;
    ICommitteeRegistry committeeRegistry;

    bytes committeeTakePubKey;
    bytes committeeDisputePubKey;
    uint32 expectedSlotId;
    bytes32 reimbursementKickoffTxid;

    function setUp(bytes32 _acceptPeginTxid) internal {
        challengeManager = getChallengeManager();
        streamManager = IStreamManager(getStreamManager());
        committeeRegistry = getCommitteeRegistry();

        StreamPosition memory streamPosition = streamManager.getStreamPosition(_acceptPeginTxid);
        expectedSlotId = uint32(streamPosition.slotId);

        uint128 committeeId = streamManager.getCommitteeId(streamPosition.streamId, streamPosition.packetNumber);
        committeeTakePubKey = committeeRegistry.getCommitteeTakePubKey(committeeId);
        committeeDisputePubKey = committeeRegistry.getCommitteeDisputePubKey(committeeId);

        reimbursementKickoffTxid = getTxid(createReimbursementKickoffTx(committeeTakePubKey, expectedSlotId));
    }

    function run(bytes32 _acceptPeginTxid) public {
        setUp(_acceptPeginTxid);

        console.log("=== Register Challenge ===");

        BtcTransaction memory challengeTx = createChallengeTx(reimbursementKickoffTxid, committeeDisputePubKey);
        BtcTxSPVProof memory challengeSPVProof = createBtcTxSPVProof(challengeTx);

        vm.startBroadcast(getDeployerKey());
        challengeManager.registerChallenge(_acceptPeginTxid, challengeSPVProof);
        vm.stopBroadcast();

        console.log("=== Challenge registered successfully ===");
    }
}
