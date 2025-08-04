// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {console} from "forge-std/Console.sol";
import {PegManager, BtcTxSPVProof} from "src/PegManager.sol";
import {ScriptUtils} from "script/helpers/ScriptUtils.sol";
import {Slot, Stream, SlotState} from "src/interfaces/IStreamManager.sol";
import {BtcTransaction} from "src/interfaces/IBitcoinManager.sol";

contract RegisterUserTakeScript is ScriptUtils {
    PegManager pegManager;

    uint64 amount;
    bytes userPubKey;
    bytes32 acceptPeginTxHash;

    Stream stream;
    uint64 expectedPacketNumber;
    uint64 expectedSlotId;

    function setUp() internal {
        pegManager = PegManager(0x0165878A594ca255338adfa4d48449f69242Eb8F);

        acceptPeginTxHash = 0x73d69e28cbe4ffc75b786b5dae8086a8112f6eb793d6891f2f900aac968a78ea;
        userPubKey = hex"02d56ad001b55eabf431e602599fcc0d7ed9d676ac93c2be11d0de6e25dd598d8b";
        amount = 100_000; // 0.001 BTC

        // Calculate expected slot and packet numbers
        stream = pegManager.streamManager().getStream(amount);
        expectedPacketNumber = stream.pegoutPacketPointer;
        expectedSlotId = stream.pegoutSlotPointer - 1; // At this point we already executed the peg out so we need to grab the previous slot
    }

    function run() public {
        setUp();

        BtcTransaction memory pegoutTx = createPegoutTx(acceptPeginTxHash, userPubKey, amount);
        BtcTxSPVProof memory pegoutTxSPVProof = createBtcTxSPVProof(pegoutTx);

        // Register peg-out transaction
        vm.startBroadcast(getDeployerKey());
        pegManager.registerUserTake(pegoutTxSPVProof);
        vm.stopBroadcast();

        Slot memory slot = pegManager.streamManager().getSlot(stream.streamId, expectedPacketNumber, expectedSlotId);
        if (slot.state != SlotState.COMPLETED) {
            revert("Slot should be marked as COMPLETED after user take peg-out registration");
        }

        console.log("=== User take Pegout registered successfully ===");
        console.log("Stream, Slot, Packet");
        console.log(stream.streamId, expectedPacketNumber, expectedSlotId);
    }
}
