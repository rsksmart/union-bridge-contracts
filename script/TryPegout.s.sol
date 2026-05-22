// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {console} from "forge-std/console.sol";
import {PegoutManager} from "src/PegoutManager.sol";
import {BtcHelper} from "src/libraries/BtcHelper.sol";
import {ScriptUtils} from "script/helpers/ScriptUtils.sol";
import {ContractAddressManager} from "script/helpers/ContractAddressManager.sol";
import {Slot, SlotLocation, Stream} from "src/interfaces/IStreamManager.sol";
import {StreamManager} from "src/StreamManager.sol";

contract TryPegoutScript is ScriptUtils, ContractAddressManager {
    PegoutManager pegoutManager;
    StreamManager streamManager;
    uint64 amountInSatoshi;
    bytes userPubKey;

    function setUp() internal {
        // ====== Arguments ======
        pegoutManager = getPegoutManager();
        streamManager = getStreamManager();
        amountInSatoshi = 100_000; // 0.001 BTC
        userPubKey = hex"02d56ad001b55eabf431e602599fcc0d7ed9d676ac93c2be11d0de6e25dd598d8b";
    }

    function run() public {
        setUp();

        console.log("=== Try Pegout ===");
        Stream memory stream = streamManager.getStream(amountInSatoshi);
        SlotLocation memory slotLocation = streamManager.getNextPegoutSlotLocation(stream.streamId);

        vm.startBroadcast(getDeployerKey());
        pegoutManager.tryPegout{value: BtcHelper.satoshiToWei(amountInSatoshi)}(userPubKey);
        vm.stopBroadcast();

        Slot memory slot = streamManager.getSlot(stream.streamId, slotLocation.packetId, slotLocation.slotId);
        bytes32 pegoutTxid = pegoutManager.getPegoutStartInfo(slot.acceptPeginTx).pegoutTxid;

        // console.log("=== Pegout accepted successfully ===");
        // console.log("pegoutTxid");
        // console.logBytes32(pegoutTxid);
        // console.log("Stream, Packet, Slot");
        // console.log(stream.streamId, slotLocation.packetId, slotLocation.slotId);
    }
}
