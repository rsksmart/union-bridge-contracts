// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {PegManager, StreamPosition, BtcTxSPVProof, PegStatus, RequestPeginTempInfo} from "src/PegManager.sol";
import {IBitcoinManager, BtcTransaction, BtcTxIn, BtcTxOut} from "src/interfaces/IBitcoinManager.sol";
import {Stream, Packet, IStreamManager} from "src/interfaces/IStreamManager.sol";
import {OpCodes} from "src/libraries/OpCodes.sol";
import {ChainIds} from "src/libraries/Network.sol";
import {Constants} from "src/libraries/Constants.sol";
import {ScriptUtils} from "script/helpers/ScriptUtils.sol";

contract AcceptPeginRequestScript is ScriptUtils {
    PegManager pegManager;
    IStreamManager streamManager;
    IBitcoinManager bitcoinManager;

    function setUp() internal returns (BtcTxSPVProof memory peginAcceptedTxSPVProof) {
        // ====== Arguments ======
        // This is the peg-in request transaction hash that was previously registered
        bytes32 requestPeginTxHash = 0x8264f7a960bc2f030c740ff08089b202adb73b820a3d7e174edc7626806905bf;
        // The other data is obtained from the peg-in request transaction
        pegManager = PegManager(0x0165878A594ca255338adfa4d48449f69242Eb8F);
        // =======================
        // Smart contract addresses
        streamManager = IStreamManager(pegManager.streamManager());
        bitcoinManager = IBitcoinManager(pegManager.bitcoinManager());

        // Check if the peg-in request exists and is in REGISTERED status
        StreamPosition memory streamPosition = pegManager.getStreamPosition(requestPeginTxHash);
        if (streamPosition.pegStatus != PegStatus.REGISTERED) {
            revert("PeginRequest not registered or already accepted");
        }

        // Get the peg-in request temporary info
        RequestPeginTempInfo memory requestPeginTempInfo = pegManager.getRequestPeginTempInfo(requestPeginTxHash);

        // Get the committee public key
        bytes32 committeePubKey = streamManager.getCommitteePubKey(streamPosition.streamId, streamPosition.packetNumber);

        // BtcTransaction to verify
        BtcTransaction memory btcTransaction =
            BtcTransaction({version: 2, inputs: new BtcTxIn[](1), outputs: new BtcTxOut[](2), locktime: 0});

        // Input consuming the peg-in request UTXO
        btcTransaction.inputs[0] = BtcTxIn({
            txId: requestPeginTxHash,
            vout: 0, // VOUT_INDEX_TAPTREE is 0
            scriptSig: hex"",
            sequence: 0xFFFFFFFD
        });

        // Pegin P2TR output
        Stream memory stream = streamManager.getStreamById(streamPosition.streamId);
        btcTransaction.outputs[0] = BtcTxOut({
            amount: stream.denomination - Constants.P2TR_FEE - Constants.SPEED_UP_AMOUNT,
            scriptPubKey: bitcoinManager.getAcceptPeginP2TRScriptPub(committeePubKey)
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

    function run() public {
        BtcTxSPVProof memory peginAcceptedTxSPVProof = setUp();
        // get Tx hash
        bytes32 peginAcceptedTxHash = bitcoinManager.getBtcTxHash(peginAcceptedTxSPVProof.btcTx);
        console.log("peginAcceptedTxHash");
        console.logBytes32(peginAcceptedTxHash);

        // accept peginRequest
        vm.startBroadcast(getDeployerKey());
        pegManager.acceptPegin(peginAcceptedTxSPVProof);
        vm.stopBroadcast();

        // check if peginRequest is accepted
        bytes32 requestPeginTxHash = peginAcceptedTxSPVProof.btcTx.inputs[0].txId;
        StreamPosition memory streamPosition = pegManager.getStreamPosition(requestPeginTxHash);
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
