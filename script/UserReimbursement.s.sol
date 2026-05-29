// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {console} from "forge-std/console.sol";
import {PeginManager} from "src/PeginManager.sol";
import {RequestPeginTempInfo} from "src/interfaces/IPeginManager.sol";
import {BtcTxSPVProof, StreamPosition, PegStatus} from "src/interfaces/IPegCommonTypes.sol";
import {IBitcoinManager, BtcTransaction} from "src/interfaces/IBitcoinManager.sol";
import {Stream, IStreamManager} from "src/interfaces/IStreamManager.sol";
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

        // Create the user reimbursement transaction
        BtcTransaction memory userReimbursementTx = createBtcUserReimbursementTx(
            _requestPeginTxid, stream.denomination, requestPeginTempInfo.btcReimbursementPubKey
        );

        // Create the SPV proof for the user reimbursement transaction
        userReimbursementTxSPVProof = createBtcTxSPVProof(userReimbursementTx);
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
