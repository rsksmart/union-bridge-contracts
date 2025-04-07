// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {PegManager} from "src/PegManager.sol";
import {ChainIds} from "src/libraries/Network.sol";
import {BtcHelper} from "src/libraries/BtcHelper.sol";

contract RegisterPegOutRequestScript is Script {
    PegManager pegManager;
    uint64 amount;
    uint256 amountInWei;
    bytes usrPubKey;

    function setUp() internal {
        // ====== Arguments ======
        pegManager = PegManager(0x0165878A594ca255338adfa4d48449f69242Eb8F);
        amount = 100_000; // 0.001 BTC
        amountInWei = BtcHelper.satoshiToWei(amount);
        usrPubKey = hex"02d56ad001b55eabf431e602599fcc0d7ed9d676ac93c2be11d0de6e25dd598d8b";
    }

    function run() public {
        setUp();

        console.log("=== Request PegOut ===");
        vm.startBroadcast();
        pegManager.requestPegOut{value: amountInWei}(usrPubKey, false);
        vm.stopBroadcast();

        bytes32 key = keccak256(abi.encodePacked(usrPubKey, amount));
        bytes32 pegOutTxHash = pegManager.getPegOutTxHash(key);
        if (pegOutTxHash == bytes32(0)) {
            revert("PegOutRequest not accepted");
        }

        console.log("=== PegOutRequest accepted successfully ===");
        console.log("PegOutTxHash");
        console.logBytes32(pegOutTxHash);
    }
}
