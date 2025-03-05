// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {CommitteeRegistry} from "src/CommitteeRegistry.sol";
import {BitcoinManager} from "src/BitcoinManager.sol";
import {PegManager} from "src/PegManager.sol";

///@dev We are using fundry-upgrades see https://github.com/OpenZeppelin/openzeppelin-foundry-upgrades
contract SetUpStreams is Script {
    // Contracts to be deployed
    bytes32 public committeePubKey;

    function setUp() internal {
        // RSK Mainnet
        if (block.chainid == 30) {
            committeePubKey = 0x924c163b385af7093440184af6fd6244936d1288cbb41cc3812286d3f83a3329;
        } else if (block.chainid == 31) {
            // RSK Testnet
            committeePubKey = 0x924c163b385af7093440184af6fd6244936d1288cbb41cc3812286d3f83a3329;
        } else if (block.chainid == 31337 || block.chainid == 1337) {
            // Foundry local chainid
            committeePubKey = 0x924c163b385af7093440184af6fd6244936d1288cbb41cc3812286d3f83a3329;
        } else {
            revert("Blockchain is not RSK or regtest");
        }
    }

    function run(PegManager _pegManager) public {
        setUp();
        _pegManager.createPacketsAndSlots(committeePubKey);
    }
}
