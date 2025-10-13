// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {console} from "forge-std/console.sol";
import {Script} from "forge-std/Script.sol";
import {PegManager} from "src/PegManager.sol";
import {ContractAddressManager} from "script/helpers/ContractAddressManager.sol";

contract GetTemporaryAddressScript is Script, ContractAddressManager {
    PegManager pegManager;
    address rootstock_deposit_address;
    uint64 value;
    bytes32 btc_reimbursement_pub_key;

    function setUp() internal {
        // ====== Arguments ======
        rootstock_deposit_address = 0x7Ac5496aee77c1bA1F0854206A26DdA82A81d6d8;
        value = 100_000;
        btc_reimbursement_pub_key = 0x7d235c24420b2f55450c8414725aa74e6db01035245efdab0e1cfa7ab29aca0f;
        pegManager = PegManager(getPegManager());
    }

    function run() public {
        setUp();

        (string memory result, uint64 packetNumber) =
            pegManager.getTemporaryPeginAddress(rootstock_deposit_address, value, btc_reimbursement_pub_key);
        console.log("=== getTemporaryPeginAddress ==");
        console.log(result);
        console.log("=== Packet Number ===");
        console.log(packetNumber);
    }
}
