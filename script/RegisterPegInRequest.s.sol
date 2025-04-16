// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {PegManager, StreamPosition, BtcTxSPVProof, PegStatus} from "src/PegManager.sol";
import {IBitcoinManager, BtcTransaction, BtcTxIn, BtcTxOut} from "src/interfaces/IBitcoinManager.sol";
import {Stream, Packet} from "src/interfaces/IStreamManager.sol";
import {OpCodes} from "src/libraries/OpCodes.sol";
import {BridgeMock} from "test/helpers/BridgeMock.sol";
import {ChainIds} from "src/libraries/Network.sol";

contract RegisterPegInRequestScript is Script {
    PegManager pegManager;
    IBitcoinManager bitcoinManager;

    function setUp() internal returns (BtcTxSPVProof memory pegInRequestTxSPVProof) {
        // ====== Arguments ======
        address rskDestinationAddress = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
        uint64 value = 100_000;
        bytes32 btcReimbursementPubKey = 0x7d235c24420b2f55450c8414725aa74e6db01035245efdab0e1cfa7ab29aca0f;
        pegManager = PegManager(0x0165878A594ca255338adfa4d48449f69242Eb8F);
        // =======================
        // Smart contract addresses
        bitcoinManager = IBitcoinManager(pegManager.bitcoinManager());
        if (block.chainid == ChainIds.LOCAL) {
            console.log("Bridge Mock setBtcTransactionConfirmations");
            // Set Mock Bridge state to return 10 when calling getBtcTransactionConfirmations
            BridgeMock bridge = BridgeMock(payable(address(pegManager.bridge())));
            vm.startBroadcast();
            bridge.setBtcTransactionConfirmations(10);
            vm.stopBroadcast();
        }
        // Committee public key
        Stream memory stream = pegManager.getStream(value);
        uint64 packetNumber = stream.peginPointer;
        bytes32 committeePubKey = pegManager.getCommitteePubKey(stream.streamId, packetNumber);
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
        // PegIn P2TR output
        btcTransaction.outputs[0] = BtcTxOut({
            amount: value,
            scriptPubKey: bitcoinManager.getPegInRequestP2TRScriptPub(
                rskDestinationAddress, value, btcReimbursementPubKey, committeePubKey
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
                rskDestinationAddress,
                btcReimbursementPubKey
            )
        });
        // SPV proof to verify with the bridge.getBtcTransactionConfirmations
        pegInRequestTxSPVProof = BtcTxSPVProof({
            blockHash: 0x0000000000000000000282fa21665766e58eb6cb94e458c3ef6d4af1121e38d9,
            btcTx: btcTransaction,
            merkleBranchPath: 4285202432,
            merkleBranchHashes: new bytes32[](1)
        });
        pegInRequestTxSPVProof.merkleBranchHashes[0] =
            0x3fcef4a1ddf759a858190b89ecbd1ff3dffb49704e110b68baf5b5de7021910f;
    }

    function run() public {
        BtcTxSPVProof memory pegInRequestTxSPVProof = setUp();
        // get Tx hash
        bytes32 pegInRequestTxHash = bitcoinManager.getBtcTxHash(pegInRequestTxSPVProof.btcTx);
        console.log("pegInRequestTxHash");
        console.logBytes32(pegInRequestTxHash);
        // check if pegInRequest is already registered
        StreamPosition memory streamPosition = pegManager.getPegInRequest(pegInRequestTxHash);
        if (streamPosition.pegStatus != PegStatus.NOT_REGISTERED) {
            revert("PegInRequest already registered");
        }
        // register pegInRequest
        vm.startBroadcast();
        pegManager.registerPegInRequest(pegInRequestTxSPVProof);
        vm.stopBroadcast();
        // check if pegInRequest is registered
        streamPosition = pegManager.getPegInRequest(pegInRequestTxHash);
        if (streamPosition.pegStatus != PegStatus.REGISTERED) {
            revert("PegInRequest not registered");
        }
        console.log("=== PegInRequest registered successfully ===");
        console.log("streamId");
        console.log(streamPosition.streamId);
        console.log("packetNumber");
        console.log(streamPosition.packetNumber);
    }
}
