// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {console} from "forge-std/console.sol";
import {ScriptUtils} from "script/helpers/ScriptUtils.sol";
import {ContractAddressManager} from "script/helpers/ContractAddressManager.sol";
import {IMemberRegistry} from "src/interfaces/IMemberRegistry.sol";

contract WithdrawAvailableBalanceScript is ScriptUtils, ContractAddressManager {
    IMemberRegistry memberRegistry;

    function setUp() internal {
        memberRegistry = getMemberRegistry();
    }

    function run() public {
        setUp();

        console.log("=== Withdraw Available Balance ===");

        vm.startBroadcast();
        // msg.sender is the address derived from the interactive key
        address memberAddress = msg.sender;
        uint256 availableBalance = memberRegistry.getMemberAvailableBalance(memberAddress);
        console.log("Your address:", memberAddress);
        console.log("Available balance:", availableBalance);

        memberRegistry.withdrawAvailableBalance();
        console.log("Withdraw available balance completed");

        vm.stopBroadcast();
    }
}
