// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {console} from "forge-std/console.sol";
import {PeginManager} from "src/PeginManager.sol";
import {RequestPeginTempInfo} from "src/interfaces/IPeginManager.sol";
import {BtcTxSPVProof, StreamPosition, PegStatus} from "src/interfaces/IPegCommonTypes.sol";
import {IBitcoinManager, BtcTransaction, BtcTxIn, BtcTxOut} from "src/interfaces/IBitcoinManager.sol";
import {Stream, IStreamManager} from "src/interfaces/IStreamManager.sol";
import {OpCodes} from "src/libraries/OpCodes.sol";
import {Constants} from "src/libraries/Constants.sol";
import {ScriptUtils} from "script/helpers/ScriptUtils.sol";
import {ContractAddressManager} from "script/helpers/ContractAddressManager.sol";
import {ICommitteeRegistry, CommitteeMember} from "src/interfaces/ICommitteeRegistry.sol";
import {IMemberRegistry} from "src/interfaces/IMemberRegistry.sol";

contract RequestPeginScript is ScriptUtils, ContractAddressManager {
    PeginManager peginManager;
    IStreamManager streamManager;
    IBitcoinManager bitcoinManager;
    ICommitteeRegistry committeeRegistry;
    IMemberRegistry memberRegistry;

    function setUp(address _rskDestinationAddress) internal returns (BtcTxSPVProof memory requestPeginTxSPVProof) {
        // ====== Arguments ======
        uint64 value = 100_000;
        bytes32 btcReimbursementPubKey = 0x7d235c24420b2f55450c8414725aa74e6db01035245efdab0e1cfa7ab29aca0f;
        peginManager = PeginManager(getPeginManager());
        // =======================
        // Smart contract addresses
        streamManager = getStreamManager();
        bitcoinManager = getBitcoinManager();
        committeeRegistry = getCommitteeRegistry();
        memberRegistry = getMemberRegistry();
        // Committee public key
        Stream memory stream = streamManager.getStream(value);
        uint64 packetNumber = stream.peginPacketPointer;
        bytes memory committeePubKey = streamManager.getCommitteePubKey(stream.streamId, packetNumber);
        // BtcTransaction to verify
        BtcTransaction memory btcTransaction = BtcTransaction({
            version: Constants.BTC_TX_VERSION,
            inputs: new BtcTxIn[](1),
            outputs: new BtcTxOut[](Constants.REQUEST_PEGIN_OUTPUT_COUNT),
            locktime: Constants.LOCKTIME
        });
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
            scriptPubKey: getRequestPeginP2TRScriptPub(
                stream.timelockSettings.requestPeginTimelock,
                _rskDestinationAddress,
                value,
                btcReimbursementPubKey,
                committeePubKey
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
        // Enabler output
        uint128 committeeId = streamManager.getCommitteeId(stream.streamId, packetNumber);
        CommitteeMember[] memory committeeMembers = committeeRegistry.getCommitteeMembers(committeeId);
        bytes32[] memory disputeKeys = new bytes32[](committeeMembers.length);
        for (uint256 i = 0; i < committeeMembers.length; i++) {
            disputeKeys[i] = memberRegistry.getMemberPublicKeys(committeeMembers[i].memberAddress).covenantPubKey;
        }
        bytes memory enablerScript = bitcoinManager.getEnablerOutputP2TRScriptPub(committeePubKey, disputeKeys);
        btcTransaction.outputs[2] = BtcTxOut({amount: Constants.ENABLER_AMOUNT, scriptPubKey: enablerScript});

        // SPV proof to verify with the bridge.getBtcTransactionConfirmations
        requestPeginTxSPVProof = createBtcTxSPVProof(btcTransaction);
        return requestPeginTxSPVProof;
    }

    function run(address _rskDestinationAddress) public {
        BtcTxSPVProof memory requestPeginTxSPVProof = setUp(_rskDestinationAddress);
        // get Tx id
        bytes32 requestPeginTxid = bitcoinManager.getBtcTxid(requestPeginTxSPVProof.btcTx);
        console.log("requestPeginTxid");
        console.logBytes32(requestPeginTxid);
        // check if RequestPegin is already registered
        StreamPosition memory streamPosition = peginManager.getStreamPositionByRequestPegin(requestPeginTxid);
        if (streamPosition.pegStatus != PegStatus.NOT_REGISTERED) {
            revert("RequestPegin already registered");
        }
        // register requestPegin
        vm.recordLogs();
        vm.startBroadcast(getDeployerKey());
        peginManager.requestPegin(requestPeginTxSPVProof);
        vm.stopBroadcast();

        // NOTE: the following code is needed if we want to test the RequestPegin on alphanet with the real RSK Bridge

        // // Output encoded calldata for manual cast call
        // bytes memory callData = abi.encodeWithSignature(
        //     "requestPegin((bytes32,(uint32,(bytes32,uint32,uint32,bytes)[],(uint64,bytes)[],uint32),uint256,bytes32[]))",
        //     requestPeginTxSPVProof
        // );
        // console.log("=== ENCODED CALLDATA FOR CAST ===");
        // console.logBytes(callData);
        // console.log("=== END ENCODED CALLDATA ===");

        // // Try calling RequestPegin via vm.rpc
        // console.log("=== TRYING REQUEST PEGIN VIA VM.RPC ===");
        // string memory callDataHex = vm.toString(callData);
        // string memory pegManagerAddr = vm.toString(address(pegManager));

        // string memory params =
        //     string(abi.encodePacked('[{"to":"', pegManagerAddr, '","data":"', callDataHex, '"},"latest"]'));

        // try vm.rpc("eth_call", params) returns (bytes memory result) {
        //     console.log("RPC call success! Result length:", result.length);
        //     if (result.length > 0) {
        //         console.logBytes(result);
        //     }
        // } catch Error(string memory reason) {
        //     console.log("RPC call failed with reason:", reason);
        //     return;
        // } catch (bytes memory lowLevelData) {
        //     console.log("RPC call failed with low level data:");
        //     console.logBytes(lowLevelData);
        //     return;
        // }

        // check if RequestPegin is registered
        streamPosition = peginManager.getStreamPositionByRequestPegin(requestPeginTxid);
        if (streamPosition.pegStatus != PegStatus.REGISTERED) {
            revert("RequestPegin not registered");
        }
        console.log("=== RequestPegin registered successfully ===");
        console.log("streamId");
        console.log(streamPosition.streamId);
        console.log("packetNumber");
        console.log(streamPosition.packetNumber);
        console.log("accept pegin Tx id");
        console.logBytes32(peginManager.getAcceptPegin(requestPeginTxid));
        RequestPeginTempInfo memory requestPeginTempInfo = peginManager.getRequestPeginTempInfo(requestPeginTxid);
        console.log("accept pegin Signature Hash");
        console.logBytes32(requestPeginTempInfo.acceptPeginSignatureHash);
    }
}
