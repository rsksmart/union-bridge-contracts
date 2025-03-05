// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {CommitteeRegistry} from "src/CommitteeRegistry.sol";
import {BitcoinManager} from "src/BitcoinManager.sol";
import {PegManager} from "src/PegManager.sol";
import {DeployImplAndProxy} from "./01_DeployImplAndProxy.s.sol";
import {SetUpCommittees} from "./02_SetUpCommittees.s.sol";
import {SetUpStreams} from "./03_SetUpStreams.s.sol";

contract DeployScript is Script {
    // Contracts to be deployed
    CommitteeRegistry public committeeRegistry;
    PegManager public pegManager;
    BitcoinManager public bitcoinManager;
    address upgradableOwner;

    function setUp() internal {}

    function run() public {
        setUp();
        // deploy implementation and proxy contracts
        DeployImplAndProxy deploy = new DeployImplAndProxy();
        (committeeRegistry, bitcoinManager, pegManager) = deploy.run();
        // Set up committees
        SetUpCommittees setUpCommittees = new SetUpCommittees();
        setUpCommittees.run(committeeRegistry);
        // Set up streams
        SetUpStreams setUpStreams = new SetUpStreams();
        setUpStreams.run(pegManager);
    }
}
