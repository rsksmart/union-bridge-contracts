// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {console} from "forge-std/console.sol";
import {PeginManager} from "src/PeginManager.sol";
import {RequestPeginTempInfo} from "src/interfaces/IPeginManager.sol";
import {BtcTxSPVProof, StreamPosition, PegStatus} from "src/interfaces/IPegCommonTypes.sol";
import {IBitcoinManager, BtcTransaction, BtcTxIn, BtcTxOut} from "src/interfaces/IBitcoinManager.sol";
import {Stream, IStreamManager} from "src/interfaces/IStreamManager.sol";
import {Constants} from "src/libraries/Constants.sol";
import {ScriptUtils} from "script/helpers/ScriptUtils.sol";
import {ContractAddressManager} from "script/helpers/ContractAddressManager.sol";

contract AcceptPeginScript is ScriptUtils, ContractAddressManager {
    PeginManager peginManager;
    IStreamManager streamManager;
    IBitcoinManager bitcoinManager;

    function setUp(bytes32 _requestPeginTxid) internal returns (BtcTxSPVProof memory peginAcceptedTxSPVProof) {
        // This is the peg-in request transaction id that was previously registered
        // ====== Arguments ======
        // The other data is obtained from the peg-in request transaction
        peginManager = PeginManager(getPeginManager());
        // =======================
        // Smart contract addresses
        streamManager = IStreamManager(peginManager.streamManager());
        bitcoinManager = IBitcoinManager(peginManager.bitcoinManager());

        // Check if the peg-in request exists and is in REGISTERED status
        StreamPosition memory streamPosition = peginManager.getStreamPositionByRequestPegin(_requestPeginTxid);
        if (streamPosition.pegStatus != PegStatus.REGISTERED) {
            revert("PeginRequest not registered or already accepted");
        }

        // Get the peg-in request temporary info
        RequestPeginTempInfo memory requestPeginTempInfo = peginManager.getRequestPeginTempInfo(_requestPeginTxid);

        // Get the committee public key
        bytes memory committeePubKey =
            streamManager.getCommitteePubKey(streamPosition.streamId, streamPosition.packetNumber);

        // BtcTransaction to verify
        BtcTransaction memory btcTransaction =
            BtcTransaction({version: 2, inputs: new BtcTxIn[](1), outputs: new BtcTxOut[](2), locktime: 0});

        // Input consuming the peg-in request UTXO
        btcTransaction.inputs[0] = BtcTxIn({
            txId: _requestPeginTxid,
            vout: 0, // VOUT_INDEX_TAPTREE is 0
            scriptSig: hex"",
            sequence: 0xFFFFFFFD
        });

        // Pegin P2TR output
        Stream memory stream = streamManager.getStreamById(streamPosition.streamId);
        btcTransaction.outputs[0] = BtcTxOut({
            amount: stream.denomination - Constants.P2TR_FEE - Constants.SPEED_UP_AMOUNT,
            scriptPubKey: getAcceptPeginP2TRScriptPub(committeePubKey)
        });

        // Speed up output (child pays for parent)
        btcTransaction.outputs[1] = BtcTxOut({
            amount: Constants.SPEED_UP_AMOUNT, // SPEED_UP_AMOUNT
            scriptPubKey: bitcoinManager.getSpeedUpScriptPub(requestPeginTempInfo.btcReimbursementPubKey)
        });

        // SPV proof to verify with the bridge.getBtcTransactionConfirmations
        peginAcceptedTxSPVProof = BtcTxSPVProof({
            blockHash: 0x0000000000000000000282fa21665766e58eb6cb94e458c3ef6d4af1121e38d9,
            btcTx: btcTransaction,
            merkleBranchPath: 4285202432,
            merkleBranchHashes: new bytes32[](1)
        });
        peginAcceptedTxSPVProof.merkleBranchHashes[0] =
            0x3fcef4a1ddf759a858190b89ecbd1ff3dffb49704e110b68baf5b5de7021910f;
    }

    function run(bytes32 _requestPeginTxid) public {
        BtcTxSPVProof memory peginAcceptedTxSPVProof = setUp(_requestPeginTxid);
        // get Tx id
        bytes32 peginAcceptedTxid = bitcoinManager.getBtcTxid(peginAcceptedTxSPVProof.btcTx);
        console.log("peginAcceptedTxid");
        console.logBytes32(peginAcceptedTxid);

        // accept peginRequest
        vm.startBroadcast(getDeployerKey());
        peginManager.acceptPegin(peginAcceptedTxSPVProof);
        vm.stopBroadcast();

        // check if peginRequest is accepted
        StreamPosition memory streamPosition = peginManager.getStreamPositionByRequestPegin(_requestPeginTxid);
        if (streamPosition.pegStatus != PegStatus.ACCEPTED) {
            revert("PeginRequest not accepted");
        }

        console.log("=== PeginRequest accepted successfully ===");
        console.log("streamId");
        console.log(streamPosition.streamId);
        console.log("packetNumber");
        console.log(streamPosition.packetNumber);
        console.log("slotId");
        console.log(streamPosition.slotId);
    }
}
