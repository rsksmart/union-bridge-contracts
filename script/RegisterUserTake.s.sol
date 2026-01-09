// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {console} from "forge-std/console.sol";
import {PegoutManager} from "src/PegoutManager.sol";
import {BtcTxSPVProof} from "src/interfaces/IPegCommonTypes.sol";
import {ScriptUtils} from "script/helpers/ScriptUtils.sol";
import {ContractAddressManager} from "script/helpers/ContractAddressManager.sol";
import {Slot, Stream, SlotState} from "src/interfaces/IStreamManager.sol";
import {BtcTransaction} from "src/interfaces/IBitcoinManager.sol";

contract RegisterUserTakeScript is ScriptUtils, ContractAddressManager {
    PegoutManager pegoutManager;

    uint64 amount;
    bytes userPubKey;
    bytes32 acceptPeginTxid;

    Stream stream;
    uint64 expectedPacketNumber;
    uint64 expectedSlotId;

    function setUp() internal {
        pegoutManager = PegoutManager(getPegoutManager());

        acceptPeginTxid = 0x7edd5873b3737806dce2a3287302c25719776227e943b236e7b9aece5486f2e9;
        userPubKey = hex"02d56ad001b55eabf431e602599fcc0d7ed9d676ac93c2be11d0de6e25dd598d8b";
        amount = 100_000; // 0.001 BTC

        // Calculate expected slot and packet numbers
        stream = pegoutManager.streamManager().getStream(amount);
        expectedPacketNumber = stream.pegoutPacketPointer;
        expectedSlotId = stream.pegoutSlotPointer; // At this point we already executed the peg out
    }

    function run() public {
        setUp();

        BtcTransaction memory pegoutTx = createPegoutTx(acceptPeginTxid, userPubKey, amount);
        BtcTxSPVProof memory pegoutTxSPVProof = createBtcTxSPVProof(pegoutTx);

        // Register peg-out transaction
        vm.startBroadcast(getDeployerKey());
        pegoutManager.registerUserTake(pegoutTxSPVProof);
        vm.stopBroadcast();

        Slot memory slot = pegoutManager.streamManager().getSlot(stream.streamId, expectedPacketNumber, expectedSlotId);
        if (slot.state != SlotState.COMPLETED) {
            revert("Slot should be marked as COMPLETED after user take peg-out registration");
        }

        console.log("=== User take Pegout registered successfully ===");
        console.log("Stream, Slot, Packet");
        console.log(stream.streamId, expectedPacketNumber, expectedSlotId);
    }
}
