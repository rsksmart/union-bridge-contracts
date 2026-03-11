// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {console} from "forge-std/console.sol";
import {ScriptUtils} from "script/helpers/ScriptUtils.sol";
import {ContractAddressManager} from "script/helpers/ContractAddressManager.sol";
import {Slot, SlotState, IStreamManager} from "src/interfaces/IStreamManager.sol";
import {ICommitteeRegistry} from "src/interfaces/ICommitteeRegistry.sol";
import {IMemberRegistry} from "src/interfaces/IMemberRegistry.sol";
import {PeginManager} from "src/PeginManager.sol";
import {BtcTransaction} from "src/interfaces/IBitcoinManager.sol";
import {BtcTxSPVProof, StreamPosition} from "src/interfaces/IPegCommonTypes.sol";
import {BtcHelper} from "src/libraries/BtcHelper.sol";

contract BlockSlotScript is ScriptUtils, ContractAddressManager {
    PeginManager peginManager;
    IStreamManager streamManager;
    IMemberRegistry memberRegistry;
    bytes operatorPubKey;

    function setUp(bytes32 _requestPeginTxid) internal returns (BtcTxSPVProof memory rejectPeginTxSPVProof) {
        peginManager = PeginManager(getPeginManager());
        ICommitteeRegistry registry = ICommitteeRegistry(getCommitteeRegistry());
        streamManager = peginManager.streamManager();
        memberRegistry = registry.memberRegistry();

        operatorPubKey =
            BtcHelper.compactPubKeyToBytes(memberRegistry.getMemberPublicKeys(getDeployerAddress()).disputePubKey);

        // Reject Pegin Btc transaction to verify
        BtcTransaction memory rejectPeginTx = createRejectPeginTx(_requestPeginTxid, operatorPubKey);

        // SPV proof to verify with the bridge.getBtcTransactionConfirmations
        rejectPeginTxSPVProof = createBtcTxSPVProof(rejectPeginTx);

        return rejectPeginTxSPVProof;
    }

    function run(bytes32 _requestPeginTxid) public {
        BtcTxSPVProof memory rejectPeginTxSPVProof = setUp(_requestPeginTxid);

        console.log("=== Reject Pegin Txid: ===");
        console.logBytes32(_requestPeginTxid);

        // Check current slot state
        StreamPosition memory streamPosition = peginManager.getStreamPositionByRequestPegin(_requestPeginTxid);
        Slot memory slot =
            streamManager.getSlot(streamPosition.streamId, streamPosition.packetNumber, streamPosition.slotId);
        console.log("Current slot state:", uint256(slot.state));

        if (slot.state != SlotState.RESERVED) {
            revert("Slot is not in RESERVED state - cannot reject pegin");
        }

        // Block the slot
        vm.startBroadcast(getDeployerKey());
        peginManager.rejectPegin(rejectPeginTxSPVProof);
        vm.stopBroadcast();

        // Verify slot was blocked
        slot = streamManager.getSlot(streamPosition.streamId, streamPosition.packetNumber, streamPosition.slotId);
        if (slot.state != SlotState.BLOCKED) {
            revert("Slot was not blocked successfully");
        }

        console.log("=== Pegin rejected successfully - Slot blocked ===");
        console.log("Stream ID:", streamPosition.streamId);
        console.log("Packet Number:", streamPosition.packetNumber);
        console.log("Slot ID:", streamPosition.slotId);
        console.log("New slot state:", uint256(slot.state));
    }
}
