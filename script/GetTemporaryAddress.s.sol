// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {PegManager} from "src/PegManager.sol";
import {Stream, Packet} from "src/interfaces/IStreamManager.sol";
import {ChainIds} from "src/libraries/Network.sol";

contract GetTemporaryAddressScript is Script {
    PegManager pegManager;
    address rootstock_deposit_address;
    uint64 value;
    bytes32 btc_reimbursement_pub_key;

    function setUp() internal {
        // ====== Arguments ======
        rootstock_deposit_address = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
        value = 100_000;
        btc_reimbursement_pub_key = 0xc72a9f6fc8e57f1de528a48b6c4ad7a6db30b24a7bbf8cdd74b0a3b248b6f7f1;
        pegManager = PegManager(0x0165878A594ca255338adfa4d48449f69242Eb8F);
    }

    function run() public {
        setUp();

        string memory result =
            pegManager.getTemporaryPegInAddress(rootstock_deposit_address, value, btc_reimbursement_pub_key);
        console.log("=== getTemporaryPegInAddress ==");
        console.log(result);
    }
}
