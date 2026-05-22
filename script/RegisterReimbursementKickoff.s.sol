// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {console} from "forge-std/console.sol";
import {BtcTxSPVProof, StreamPosition} from "src/interfaces/IPegCommonTypes.sol";
import {ScriptUtils} from "script/helpers/ScriptUtils.sol";
import {ContractAddressManager} from "script/helpers/ContractAddressManager.sol";
import {IStreamManager} from "src/interfaces/IStreamManager.sol";
import {BtcTransaction} from "src/interfaces/IBitcoinManager.sol";
import {IOperatorTakeManager} from "src/interfaces/IOperatorTakeManager.sol";
import {ICommitteeRegistry} from "src/interfaces/ICommitteeRegistry.sol";

contract RegisterReimbursementKickoffScript is ScriptUtils, ContractAddressManager {
    IOperatorTakeManager operatorTakeManager;
    IStreamManager streamManager;
    ICommitteeRegistry committeeRegistry;

    bytes committeePubKey;
    uint32 expectedSlotId;

    function setUp(bytes32 _acceptPeginTxid) internal {
        operatorTakeManager = getOperatorTakeManager();
        streamManager = IStreamManager(getStreamManager());
        committeeRegistry = getCommitteeRegistry();

        StreamPosition memory streamPosition = streamManager.getStreamPosition(_acceptPeginTxid);
        expectedSlotId = uint32(streamPosition.slotId);

        uint128 committeeId = streamManager.getCommitteeId(streamPosition.streamId, streamPosition.packetNumber);
        committeePubKey = committeeRegistry.getCommitteeTakePubKey(committeeId);
    }

    function run(bytes32 _acceptPeginTxid) public {
        setUp(_acceptPeginTxid);

        console.log("=== Register Reimbursement Kickoff ===");

        BtcTransaction memory kickoffTx = createReimbursementKickoffTx(committeePubKey, expectedSlotId);
        BtcTxSPVProof memory kickoffTxSPVProof = createBtcTxSPVProof(kickoffTx);

        vm.startBroadcast(getDeployerKey());
        operatorTakeManager.registerReimbursementKickoff(_acceptPeginTxid, kickoffTxSPVProof);
        vm.stopBroadcast();

        console.log("=== Reimbursement Kickoff registered successfully ===");
    }
}
