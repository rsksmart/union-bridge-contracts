// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {console} from "forge-std/console.sol";
import {ScriptUtils} from "script/helpers/ScriptUtils.sol";
import {ContractAddressManager} from "script/helpers/ContractAddressManager.sol";
import {PegoutManager} from "src/PegoutManager.sol";
import {ISignatureManager, OperatorTakeData} from "src/interfaces/ISignatureManager.sol";
import {IStreamManager, Packet} from "src/interfaces/IStreamManager.sol";
import {BtcTransaction} from "src/interfaces/IBitcoinManager.sol";
import {BtcTxEncoder} from "src/libraries/BtcTxEncoder.sol";
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
    bytes userPubKey;

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
        BtcTransaction memory kickoffTx = createReimbursementKickoffTx(committeePubKey, uint32(expectedSlotId));
        bytes32 reimbursementKickoffTxid = BtcHelper.hash256(BtcTxEncoder.encodeTx(kickoffTx));

        // OPERATOR TAKE
        BtcTransaction memory takeTx =
            createOperatorTakeTx(_acceptPeginTxid, reimbursementKickoffTxid, operatorPubKey, amount);
        bytes32 takeTxid = BtcHelper.hash256(BtcTxEncoder.encodeTx(takeTx));
        // Fake won txid for testing
        bytes32 wonTxid = hex"1218969313e0736d427f4f1828fd9bfb2785df07053fe43baca6cb1a9438d349";

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
