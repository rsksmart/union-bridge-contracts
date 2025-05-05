// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {CommitteeRegistry} from "src/CommitteeRegistry.sol";
import {BitcoinManager} from "src/BitcoinManager.sol";
import {PegManager} from "src/PegManager.sol";
import {StreamManager} from "src/StreamManager.sol";
import {DeployImplAndProxy} from "./01_DeployImplAndProxy.s.sol";
import {SetUpCommittees} from "./02_SetUpCommittees.s.sol";
import {SetUpStreams} from "./03_SetUpStreams.s.sol";

contract DeployScript is Script {
    // Contracts to be deployed
    CommitteeRegistry public committeeRegistry;
    PegManager public pegManager;
    BitcoinManager public bitcoinManager;
    StreamManager public streamManager;
    address public upgradableOwner;
    address payable public bridgeAddress;

    function setUp() internal {}

    function run() public {
        setUp();
        // deploy implementation and proxy contracts
        DeployImplAndProxy deploy = new DeployImplAndProxy();
        (committeeRegistry, bitcoinManager, pegManager, streamManager, upgradableOwner, bridgeAddress) = deploy.run();
        // Set up committees
        SetUpCommittees setUpCommittees = new SetUpCommittees();
        setUpCommittees.run(committeeRegistry);
        // Set up streams
        SetUpStreams setUpStreams = new SetUpStreams();
        setUpStreams.run(streamManager);
    }
}
