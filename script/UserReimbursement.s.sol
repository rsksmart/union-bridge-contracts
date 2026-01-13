// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {console} from "forge-std/console.sol";
import {PeginManager} from "src/PeginManager.sol";
import {RequestPeginTempInfo} from "src/interfaces/IPeginManager.sol";
import {BtcTxSPVProof, StreamPosition, PegStatus} from "src/interfaces/IPegCommonTypes.sol";
import {IBitcoinManager, BtcTransaction, BtcTxIn, BtcTxOut} from "src/interfaces/IBitcoinManager.sol";
import {Stream, IStreamManager} from "src/interfaces/IStreamManager.sol";
import {Constants} from "src/libraries/Constants.sol";
import {BtcScriptParser} from "src/libraries/BtcScriptParser.sol";
import {BtcHelper} from "src/libraries/BtcHelper.sol";
import {ScriptUtils} from "script/helpers/ScriptUtils.sol";
import {ContractAddressManager} from "script/helpers/ContractAddressManager.sol";

contract UserReimbursementScript is ScriptUtils, ContractAddressManager {
    PeginManager peginManager;
    IStreamManager streamManager;
    IBitcoinManager bitcoinManager;

    function setUp(bytes32 _requestPeginTxid) internal returns (BtcTxSPVProof memory userReimbursementTxSPVProof) {
        peginManager = PeginManager(getPeginManager());
        streamManager = IStreamManager(peginManager.streamManager());
        bitcoinManager = IBitcoinManager(peginManager.bitcoinManager());

        // Check if the request pegin exists and is in REGISTERED status
        StreamPosition memory streamPosition = peginManager.getStreamPositionByRequestPegin(_requestPeginTxid);
        if (streamPosition.pegStatus != PegStatus.REGISTERED) {
            revert("RequestPegin not registered or already processed");
        }

        // Get the request pegin temporary info
        RequestPeginTempInfo memory requestPeginTempInfo = peginManager.getRequestPeginTempInfo(_requestPeginTxid);

        // Get the stream to determine the denomination
        Stream memory stream = streamManager.getStreamById(streamPosition.streamId);

        // BtcTransaction to verify
        BtcTransaction memory btcTransaction = BtcTransaction({
            version: Constants.BTC_TX_VERSION,
            inputs: new BtcTxIn[](1),
            outputs: new BtcTxOut[](1),
            locktime: 0
        });

        // Input: spend the request peg-in taptree output (vout 0)
        // This uses the timelock path after the timelock expires
        btcTransaction.inputs[0] = BtcTxIn({
            txId: _requestPeginTxid,
            vout: Constants.REQUEST_PEGIN_VOUT_TAPTREE,
            scriptSig: hex"",
            sequence: Constants.SEQUENCE
        });

        // Output: Dummy return BTC to user's reimbursement address
        // Convert the x-only pubkey to compressed format for P2WPKH
        bytes memory userReimbursementPubKey =
            BtcHelper.pubKeyXonlyToCompact(requestPeginTempInfo.btcReimbursementPubKey);

        btcTransaction.outputs[0] = BtcTxOut({
            amount: stream.denomination - Constants.P2TR_FEE,
            scriptPubKey: BtcScriptParser.getP2WPKHScript(userReimbursementPubKey)
        });

        // SPV proof to verify with the bridge.getBtcTransactionConfirmations
        userReimbursementTxSPVProof = BtcTxSPVProof({
            blockHash: 0x0000000000000000000282fa21665766e58eb6cb94e458c3ef6d4af1121e38d9,
            btcTx: btcTransaction,
            merkleBranchPath: 4285202432,
            merkleBranchHashes: new bytes32[](1)
        });
        userReimbursementTxSPVProof.merkleBranchHashes[0] =
            0x3fcef4a1ddf759a858190b89ecbd1ff3dffb49704e110b68baf5b5de7021910f;
    }

    function run(bytes32 _requestPeginTxid) public {
        BtcTxSPVProof memory userReimbursementTxSPVProof = setUp(_requestPeginTxid);

        // get Tx id
        bytes32 userReimbursementTxid = bitcoinManager.getBtcTxid(userReimbursementTxSPVProof.btcTx);
        console.log("userReimbursementTxid");
        console.logBytes32(userReimbursementTxid);

        // The input index in the user reimbursement tx that spends the request peg-in
        uint32 reimbursementPeginVin = 0;

        // Register user reimbursement
        vm.startBroadcast(getDeployerKey());
        peginManager.userReimbursement(userReimbursementTxSPVProof, reimbursementPeginVin);
        vm.stopBroadcast();

        // Verify the user reimbursement was registered
        StreamPosition memory streamPosition = peginManager.getStreamPositionByRequestPegin(_requestPeginTxid);
        if (streamPosition.pegStatus != PegStatus.BLOCKED) {
            revert("User reimbursement not registered successfully");
        }

        console.log("=== User Reimbursement registered successfully ===");
        console.log("streamId");
        console.log(streamPosition.streamId);
        console.log("packetNumber");
        console.log(streamPosition.packetNumber);
        console.log("slotId");
        console.log(streamPosition.slotId);
        console.log("pegStatus: BLOCKED");

        // Show the stored user reimbursement txid
        RequestPeginTempInfo memory peginTempInfo = peginManager.getRequestPeginTempInfo(_requestPeginTxid);
        console.log("stored userReimbursementTxid");
        console.logBytes32(peginTempInfo.userReimbursementTxid);
    }
}
