// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {console} from "forge-std/console.sol";
import {PegoutManager} from "src/PegoutManager.sol";
import {BtcTxSPVProof} from "src/interfaces/IPegCommonTypes.sol";
import {ScriptUtils} from "script/helpers/ScriptUtils.sol";
import {ContractAddressManager} from "script/helpers/ContractAddressManager.sol";
import {Slot, SlotState} from "src/interfaces/IStreamManager.sol";
import {BtcTransaction} from "src/interfaces/IBitcoinManager.sol";
import {StreamManager} from "src/StreamManager.sol";
import {StreamPosition} from "src/interfaces/IPegCommonTypes.sol";

contract RegisterUserTakeScript is ScriptUtils, ContractAddressManager {
    PegoutManager pegoutManager;
    StreamManager streamManager;

    uint64 amount;
    bytes userPubKey;
    bytes32 acceptPeginTxid;

    function setUp() internal {
        pegoutManager = getPegoutManager();
        streamManager = getStreamManager();

        acceptPeginTxid = 0x8c7ac99690001ba50f5ffc9b774fa96fdcf1b391a8e62b7fb89c415886e8b9eb;
        userPubKey = hex"02d56ad001b55eabf431e602599fcc0d7ed9d676ac93c2be11d0de6e25dd598d8b";
        amount = 100_000; // 0.001 BTC
    }

    function run() public {
        setUp();

        console.log("=== Register User Take ===");
        BtcTransaction memory pegoutTx = createPegoutTx(acceptPeginTxid, userPubKey, amount);
        BtcTxSPVProof memory pegoutTxSPVProof = createBtcTxSPVProof(pegoutTx);

        // Register peg-out transaction
        vm.startBroadcast(getDeployerKey());
        pegoutManager.registerUserTake(pegoutTxSPVProof);
        vm.stopBroadcast();

        StreamPosition memory streamPosition = streamManager.getStreamPosition(acceptPeginTxid);
        Slot memory slot =
            streamManager.getSlot(streamPosition.streamId, streamPosition.packetNumber, streamPosition.slotId);
        if (slot.state != SlotState.COMPLETED) {
            revert("Slot should be marked as COMPLETED after user take peg-out registration");
        }

        // console.log("=== User take Pegout registered successfully ===");
        // console.log("Stream, Packet, Slot");
        // console.log(streamPosition.streamId, streamPosition.packetNumber, streamPosition.slotId);
    }
}
