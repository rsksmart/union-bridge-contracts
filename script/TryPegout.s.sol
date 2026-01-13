// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {console} from "forge-std/console.sol";
import {PegoutManager} from "src/PegoutManager.sol";
import {BtcHelper} from "src/libraries/BtcHelper.sol";
import {ScriptUtils} from "script/helpers/ScriptUtils.sol";
import {ContractAddressManager} from "script/helpers/ContractAddressManager.sol";
import {Stream, IStreamManager} from "src/interfaces/IStreamManager.sol";

contract TryPegoutScript is ScriptUtils, ContractAddressManager {
    PegoutManager pegoutManager;
    IStreamManager streamManager;
    uint64 amount;
    uint256 amountInWei;
    bytes userPubKey;

    function setUp() internal {
        // ====== Arguments ======
        pegoutManager = PegoutManager(getPegoutManager());
        streamManager = IStreamManager(pegoutManager.streamManager());
        amount = 100_000; // 0.001 BTC
        amountInWei = BtcHelper.satoshiToWei(amount);
        userPubKey = hex"02d56ad001b55eabf431e602599fcc0d7ed9d676ac93c2be11d0de6e25dd598d8b";
    }

    function run() public {
        setUp();

        // Get first filled Slot
        Stream memory stream = streamManager.getStream(amount);
        uint64 packetNumber = stream.pegoutPacketPointer;
        uint64 slotId = stream.pegoutSlotPointer;

        console.log("=== Try Pegout ===");
        vm.startBroadcast(getDeployerKey());
        pegoutManager.tryPegout{value: amountInWei}(userPubKey);
        vm.stopBroadcast();

        bytes32 pegoutTxid = pegoutManager.getPegoutTxid(stream.streamId, packetNumber, slotId);
        if (pegoutTxid == bytes32(0)) {
            revert("Pegout not accepted");
        }

        console.log("=== Pegout accepted successfully ===");
        console.log("pegoutTxid");
        console.logBytes32(pegoutTxid);
        console.log("Stream, Slot, Packet");
        console.log(stream.streamId, slotId, packetNumber);
    }
}
