// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {console} from "forge-std/console.sol";
import {ScriptUtils} from "script/helpers/ScriptUtils.sol";
import {ContractAddressManager} from "script/helpers/ContractAddressManager.sol";
import {PegoutManager} from "src/PegoutManager.sol";
import {ISignatureManager, OperatorTakeData} from "src/interfaces/ISignatureManager.sol";
import {IStreamManager, Packet} from "src/interfaces/IStreamManager.sol";
import {BtcTransaction} from "src/interfaces/IBitcoinManager.sol";
import {BtcHelper} from "src/libraries/BtcHelper.sol";
import {ICommitteeRegistry} from "src/interfaces/ICommitteeRegistry.sol";
import {IMemberRegistry} from "src/interfaces/IMemberRegistry.sol";
import {StreamPosition} from "src/interfaces/IPegCommonTypes.sol";

contract addOperatorTakeTxidsScript is ScriptUtils, ContractAddressManager {
    PegoutManager pegoutManager;
    ISignatureManager signatureManager;
    uint256 privKey;
    uint16 mnemonicIndex;
    uint64 amount;

    bytes operatorPubKey;
    bytes committeePubKey;

    IStreamManager streamManager;
    uint64 expectedStreamId;
    uint64 expectedPacketNumber;
    uint64 expectedSlotId;

    function setUp(uint16 _mnemonicIndex, bytes32 _acceptPeginTxid) internal {
        pegoutManager = PegoutManager(getPegoutManager());
        signatureManager = ISignatureManager(pegoutManager.signatureManager());

        ICommitteeRegistry registry = getCommitteeRegistry();
        IMemberRegistry memberRegistry = registry.memberRegistry();

        bytes32 operatorXOnlyPubKey = memberRegistry.getMemberPublicKeys(getDeployerAddress()).covenantPubKey;

        operatorPubKey = BtcHelper.pubKeyXonlyToCompact(operatorXOnlyPubKey);
        amount = 100_000; // 0.001 BTC

        // Calculate expected slot and packet numbers
        streamManager = IStreamManager(getStreamManager());
        StreamPosition memory streamPosition = streamManager.getStreamPosition(_acceptPeginTxid);
        expectedStreamId = streamPosition.streamId;
        expectedPacketNumber = streamPosition.packetNumber;
        expectedSlotId = streamPosition.slotId;

        Packet memory packet = streamManager.getPacket(expectedStreamId, expectedPacketNumber);
        committeePubKey = packet.committeePubKey;

        // Read args from command line / env
        if (_acceptPeginTxid == bytes32(0)) {
            revert("ACCEPT_PEGIN_TXID must be provided");
        }

        mnemonicIndex = _mnemonicIndex;
        if (mnemonicIndex > 9) {
            revert("MNEMONIC_INDEX must be between 0 and 9");
        }

        privKey = getMemberKey(uint32(mnemonicIndex));
    }

    function run(uint16 _mnemonicIndex, bytes32 _acceptPeginTxid) public {
        setUp(_mnemonicIndex, _acceptPeginTxid);

        // REIMBURSEMENT KICKOFF
        BtcTransaction memory kickoffTx = createReimbursementKickoffTx(committeePubKey, expectedSlotId);
        bytes32 reimbursementKickoffTxid = getTxid(kickoffTx);

        // OPERATOR TAKE
        BtcTransaction memory takeTx =
            createOperatorTakeTx(_acceptPeginTxid, reimbursementKickoffTxid, operatorPubKey, amount);
        bytes32 takeTxid = getTxid(takeTx);

        // CHALLENGE
        BtcTransaction memory challengeTx = createChallengeTx(reimbursementKickoffTxid, committeePubKey);
        bytes32 challengeTxid = getTxid(challengeTx);

        // INPUT REVEALED
        BtcTransaction memory inputRevealedTx = createRevealTx(challengeTxid, committeePubKey);
        bytes32 inputRevealedTxid = getTxid(inputRevealedTx);

        // OPERATOR WON
        BtcTransaction memory wonTx = createOperatorWonTx(_acceptPeginTxid, inputRevealedTxid, operatorPubKey, amount);
        bytes32 wonTxid = getTxid(wonTx);

        vm.startBroadcast(privKey);
        signatureManager.addOperatorTakeTxids(_acceptPeginTxid, takeTxid, wonTxid);
        vm.stopBroadcast();

        OperatorTakeData[] memory operatorTakeData = signatureManager.getOperatorTakeData(_acceptPeginTxid);
        console.log("=== Operator take tx id added successfully ===");
        for (uint256 i = 0; i < operatorTakeData.length; i++) {
            console.log("Operator take tx id:");
            console.logBytes32(operatorTakeData[i].takeTxid);
            console.log("Operator won tx id:");
            console.logBytes32(operatorTakeData[i].wonTxid);
            console.log("Operator address:");
            console.logAddress(operatorTakeData[i].memberAddress);
        }
    }
}
