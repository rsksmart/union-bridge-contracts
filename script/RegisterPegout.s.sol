// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {PegManager, BtcTxSPVProof} from "src/PegManager.sol";
import {ScriptUtils} from "script/helpers/ScriptUtils.sol";
import {HelperContract} from "test/helpers/HelperContract.sol";
import {Slot, Stream, Packet, SlotState, IStreamManager} from "src/interfaces/IStreamManager.sol";
import {BtcTransaction} from "src/interfaces/IBitcoinManager.sol";

contract RegisterPegoutScript is ScriptUtils {
    PegManager pegManager;

    uint64 amount;
    bytes usrPubKey;
    bytes32 acceptPeginTxHash;

    Stream stream;
    uint64 expectedPacketNumber;
    uint64 expectedSlotId;

    function setUp() internal {
        pegManager = PegManager(0x0165878A594ca255338adfa4d48449f69242Eb8F);

        acceptPeginTxHash = 0x2d19c836edc3e3c8cf56600b880c2603155043f89837235ccc33885460f9c390;
        usrPubKey = hex"02d56ad001b55eabf431e602599fcc0d7ed9d676ac93c2be11d0de6e25dd598d8b";
        amount = 100_000; // 0.001 BTC

        // Calculate expected slot and packet numbers
        stream = pegManager.streamManager().getStream(amount);
        expectedPacketNumber = stream.pegoutPacketPointer;
        expectedSlotId = stream.pegoutSlotPointer - 1; // At this point we already executed the peg out so we need to grab the previous slot
    }

    function run() public {
        setUp();

        BtcTransaction memory pegoutTx = createPegoutTx(acceptPeginTxHash, usrPubKey, amount);
        BtcTxSPVProof memory pegoutTxSPVProof = createBtcTxSPVProof(pegoutTx);

        // Register peg-out transaction
        vm.startBroadcast(getDeployerKey());
        pegManager.registerPegout(pegoutTxSPVProof);
        vm.stopBroadcast();

        Slot memory slot = pegManager.streamManager().getSlot(stream.streamId, expectedPacketNumber, expectedSlotId);
        if (slot.state != SlotState.PAID) {
            revert("Slot should be marked as PAID after peg-out registration");
        }

        console.log("=== Pegout registered successfully ===");
        console.log("Stream, Slot, Packet");
        console.log(stream.streamId, expectedPacketNumber, expectedSlotId);
    }
}
