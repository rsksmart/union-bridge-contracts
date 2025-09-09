// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {console} from "forge-std/console.sol";
import {PegManager, StreamPosition, BtcTxSPVProof, PegStatus, RequestPeginTempInfo} from "src/PegManager.sol";
import {IBitcoinManager, BtcTransaction, BtcTxIn, BtcTxOut} from "src/interfaces/IBitcoinManager.sol";
import {Stream, IStreamManager} from "src/interfaces/IStreamManager.sol";
import {OpCodes} from "src/libraries/OpCodes.sol";
import {ScriptUtils} from "script/helpers/ScriptUtils.sol";

contract RequestPeginScript is ScriptUtils {
    PegManager pegManager;
    IStreamManager streamManager;
    IBitcoinManager bitcoinManager;

    function setUp(address _rskDestinationAddress) internal returns (BtcTxSPVProof memory peginRequestTxSPVProof) {
        // ====== Arguments ======
        uint64 value = 100_000;
        bytes32 btcReimbursementPubKey = 0x7d235c24420b2f55450c8414725aa74e6db01035245efdab0e1cfa7ab29aca0f;
        pegManager = PegManager(0x0165878A594ca255338adfa4d48449f69242Eb8F);
        // =======================
        // Smart contract addresses
        streamManager = IStreamManager(pegManager.streamManager());
        bitcoinManager = IBitcoinManager(pegManager.bitcoinManager());
        // Committee public key
        Stream memory stream = streamManager.getStream(value);
        uint64 packetNumber = stream.peginPacketPointer;
        bytes memory committeePubKey = streamManager.getCommitteePubKey(stream.streamId, packetNumber);
        // BtcTransaction to verify
        BtcTransaction memory btcTransaction =
            BtcTransaction({version: 2, inputs: new BtcTxIn[](1), outputs: new BtcTxOut[](2), locktime: 0});
        // User funding tx
        btcTransaction.inputs[0] = BtcTxIn({
            txId: 0x360b81785dc7c2f40627fea364676dbb73e6276683caffd9f906b0e0bd36b3d2,
            vout: 1694,
            scriptSig: hex"",
            sequence: 4294967293
        });
        // Pegin P2TR output
        btcTransaction.outputs[0] = BtcTxOut({
            amount: value,
            scriptPubKey: bitcoinManager.getPeginRequestP2TRScriptPub(
                _rskDestinationAddress, value, btcReimbursementPubKey, committeePubKey
            )
        });
        // OP_RETURN output
        btcTransaction.outputs[1] = BtcTxOut({
            amount: 0,
            scriptPubKey: abi.encodePacked(
                OpCodes.OP_RETURN,
                OpCodes.OP_PUSHBYTES_69,
                "RSK_PEGIN",
                packetNumber,
                _rskDestinationAddress,
                btcReimbursementPubKey
            )
        });
        // SPV proof to verify with the bridge.getBtcTransactionConfirmations
        peginRequestTxSPVProof = BtcTxSPVProof({
            blockHash: 0x0000000000000000000282fa21665766e58eb6cb94e458c3ef6d4af1121e38d9,
            btcTx: btcTransaction,
            merkleBranchPath: 4285202432,
            merkleBranchHashes: new bytes32[](1)
        });
        peginRequestTxSPVProof.merkleBranchHashes[0] =
            0x3fcef4a1ddf759a858190b89ecbd1ff3dffb49704e110b68baf5b5de7021910f;
    }

    function run(address _rskDestinationAddress) public {
        BtcTxSPVProof memory peginRequestTxSPVProof = setUp(_rskDestinationAddress);
        // get Tx hash
        bytes32 peginRequestTxHash = bitcoinManager.getBtcTxHash(peginRequestTxSPVProof.btcTx);
        console.log("peginRequestTxHash");
        console.logBytes32(peginRequestTxHash);
        // check if peginRequest is already registered
        StreamPosition memory streamPosition = pegManager.getStreamPosition(peginRequestTxHash);
        if (streamPosition.pegStatus != PegStatus.NOT_REGISTERED) {
            revert("PeginRequest already registered");
        }
        // register peginRequest
        vm.recordLogs();
        vm.startBroadcast(getDeployerKey());
        pegManager.requestPegin(peginRequestTxSPVProof);
        vm.stopBroadcast();
        // check if peginRequest is registered
        streamPosition = pegManager.getStreamPosition(peginRequestTxHash);
        if (streamPosition.pegStatus != PegStatus.REGISTERED) {
            revert("PeginRequest not registered");
        }
        console.log("=== PeginRequest registered successfully ===");
        console.log("streamId");
        console.log(streamPosition.streamId);
        console.log("packetNumber");
        console.log(streamPosition.packetNumber);
        console.log("accept pegin Tx Hash");
        console.logBytes32(pegManager.getPeginRequest(peginRequestTxHash));
        RequestPeginTempInfo memory requestPeginTempInfo = pegManager.getRequestPeginTempInfo(peginRequestTxHash);
        console.log("accept pegin Signature Hash");
        console.logBytes32(requestPeginTempInfo.acceptPeginSignatureHash);
    }
}
