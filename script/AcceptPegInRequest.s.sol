// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {PegManager, StreamPosition, BtcTxSPVProof, PegStatus, RequestPegInTempInfo} from "src/PegManager.sol";
import {IBitcoinManager, BtcTransaction, BtcTxIn, BtcTxOut} from "src/interfaces/IBitcoinManager.sol";
import {Stream, Packet} from "src/interfaces/IStreamManager.sol";
import {OpCodes} from "src/libraries/OpCodes.sol";
import {ChainIds} from "src/libraries/Network.sol";
import {Constants} from "src/libraries/Constants.sol";

contract AcceptPegInRequestScript is Script {
    PegManager pegManager;
    IBitcoinManager bitcoinManager;

    function setUp() internal returns (BtcTxSPVProof memory pegInAcceptedTxSPVProof) {
        // ====== Arguments ======
        // This is the peg-in request transaction hash that was previously registered
        bytes32 requestPegInTxHash = 0x8264f7a960bc2f030c740ff08089b202adb73b820a3d7e174edc7626806905bf;
        // The other data is obtained from the peg-in request transaction
        pegManager = PegManager(0x0165878A594ca255338adfa4d48449f69242Eb8F);
        // =======================
        // Smart contract addresses
        bitcoinManager = IBitcoinManager(pegManager.bitcoinManager());

        // Check if the peg-in request exists and is in REGISTERED status
        StreamPosition memory streamPosition = pegManager.getPegInRequest(requestPegInTxHash);
        if (streamPosition.pegStatus != PegStatus.REGISTERED) {
            revert("PegInRequest not registered or already accepted");
        }

        // Get the peg-in request temporary info
        RequestPegInTempInfo memory requestPegInTempInfo = pegManager.getRequestPegInTempInfo(requestPegInTxHash);

        // Get the committee public key
        bytes32 committeePubKey = pegManager.getCommitteePubKey(streamPosition.streamId, streamPosition.packetNumber);

        // BtcTransaction to verify
        BtcTransaction memory btcTransaction =
            BtcTransaction({version: 2, inputs: new BtcTxIn[](1), outputs: new BtcTxOut[](2), locktime: 0});

        // Input consuming the peg-in request UTXO
        btcTransaction.inputs[0] = BtcTxIn({
            txId: requestPegInTxHash,
            vout: 0, // VOUT_INDEX_TAPTREE is 0
            scriptSig: hex"",
            sequence: 0xFFFFFFFD
        });

        // PegIn P2TR output
        btcTransaction.outputs[0] = BtcTxOut({
            amount: requestPegInTempInfo.outputAmount - Constants.P2TR_FEE - Constants.SPEED_UP_AMOUNT,
            scriptPubKey: bitcoinManager.getAcceptPegInP2TRScriptPub(committeePubKey)
        });

        // Speed up output (child pays for parent)
        btcTransaction.outputs[1] = BtcTxOut({
            amount: Constants.SPEED_UP_AMOUNT, // SPEED_UP_AMOUNT
            scriptPubKey: bitcoinManager.getSpeedUpScriptPub(requestPegInTempInfo.btcReimbursementPubKey)
        });

        // SPV proof to verify with the bridge.getBtcTransactionConfirmations
        pegInAcceptedTxSPVProof = BtcTxSPVProof({
            blockHash: 0x0000000000000000000282fa21665766e58eb6cb94e458c3ef6d4af1121e38d9,
            btcTx: btcTransaction,
            merkleBranchPath: 4285202432,
            merkleBranchHashes: new bytes32[](1)
        });
        pegInAcceptedTxSPVProof.merkleBranchHashes[0] =
            0x3fcef4a1ddf759a858190b89ecbd1ff3dffb49704e110b68baf5b5de7021910f;
    }

    function run() public {
        BtcTxSPVProof memory pegInAcceptedTxSPVProof = setUp();
        // get Tx hash
        bytes32 pegInAcceptedTxHash = bitcoinManager.getBtcTxHash(pegInAcceptedTxSPVProof.btcTx);
        console.log("pegInAcceptedTxHash");
        console.logBytes32(pegInAcceptedTxHash);

        // accept pegInRequest
        vm.startBroadcast();
        pegManager.acceptPegInRequest(pegInAcceptedTxSPVProof);
        vm.stopBroadcast();

        // check if pegInRequest is accepted
        bytes32 requestPegInTxHash = pegInAcceptedTxSPVProof.btcTx.inputs[0].txId;
        StreamPosition memory streamPosition = pegManager.getPegInRequest(requestPegInTxHash);
        if (streamPosition.pegStatus != PegStatus.ACCEPTED) {
            revert("PegInRequest not accepted");
        }

        console.log("=== PegInRequest accepted successfully ===");
        console.log("streamId");
        console.log(streamPosition.streamId);
        console.log("packetNumber");
        console.log(streamPosition.packetNumber);
        console.log("slotId");
        console.log(streamPosition.slotId);
    }
}
