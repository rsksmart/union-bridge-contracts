// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {console} from "forge-std/console.sol";
import {Script} from "forge-std/Script.sol";
import {PeginManager} from "src/PeginManager.sol";
import {ContractAddressManager} from "script/helpers/ContractAddressManager.sol";

contract GetTemporaryAddressScript is Script, ContractAddressManager {
    PeginManager peginManager;
    address rootstock_deposit_address;
    uint64 value;
    bytes32 btc_reimbursement_pub_key;

    function setUp() internal {
        // ====== Arguments ======
        rootstock_deposit_address = 0x7Ac5496aee77c1bA1F0854206A26DdA82A81d6d8;
        value = 100_000;
        btc_reimbursement_pub_key = 0x7d235c24420b2f55450c8414725aa74e6db01035245efdab0e1cfa7ab29aca0f;
        peginManager = PeginManager(getPeginManager());
    }

    function run() public {
        setUp();

        (string memory result, uint64 packetNumber, bytes32[] memory memberDisputeKeys, uint64 availableSlots) =
            peginManager.getRequestPeginData(rootstock_deposit_address, value, btc_reimbursement_pub_key);
        console.log("=== getRequestPeginData ===");
        console.log(result);
        console.log("=== Packet Number ===");
        console.log(packetNumber);
        console.log("=== Available Slots ===");
        console.log(availableSlots);
        console.log("=== Member Dispute Keys ===");
        for (uint256 i = 0; i < memberDisputeKeys.length; i++) {
            console.log("Member", i, ":");
            console.logBytes32(memberDisputeKeys[i]);
        }
    }
}
