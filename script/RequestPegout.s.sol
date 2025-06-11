// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {PegManager} from "src/PegManager.sol";
import {ChainIds} from "src/libraries/Network.sol";
import {BtcHelper} from "src/libraries/BtcHelper.sol";
import {ScriptUtils} from "script/helpers/ScriptUtils.sol";
import {Slot, Stream, Packet, SlotState, IStreamManager} from "src/interfaces/IStreamManager.sol";

contract RequestPegoutScript is ScriptUtils {
    PegManager pegManager;
    IStreamManager streamManager;
    uint64 amount;
    uint256 amountInWei;
    bytes usrPubKey;

    function setUp() internal {
        // ====== Arguments ======
        pegManager = PegManager(0x0165878A594ca255338adfa4d48449f69242Eb8F);
        streamManager = IStreamManager(pegManager.streamManager());
        amount = 100_000; // 0.001 BTC
        amountInWei = BtcHelper.satoshiToWei(amount);
        usrPubKey = hex"02d56ad001b55eabf431e602599fcc0d7ed9d676ac93c2be11d0de6e25dd598d8b";
    }

    function run() public {
        setUp();

        // Get first filled Slot
        Stream memory stream = streamManager.getStream(amount);
        uint64 packetNumber = stream.pegoutPacketPointer;
        uint64 slotId = stream.pegoutSlotPointer;

        console.log("=== Request Pegout ===");
        vm.startBroadcast(getDeployerKey());
        pegManager.requestPegout{value: amountInWei}(usrPubKey);
        vm.stopBroadcast();

        bytes32 pegoutSignatureHash = pegManager.getPegoutSignatureHash(stream.streamId, packetNumber, slotId);
        if (pegoutSignatureHash == bytes32(0)) {
            revert("PegoutRequest not accepted");
        }

        console.log("=== PegoutRequest accepted successfully ===");
        console.log("pegoutSignatureHash");
        console.logBytes32(pegoutSignatureHash);
        console.log("Stream, Slot, Packet");
        console.log(stream.streamId, slotId, packetNumber);
    }
}
