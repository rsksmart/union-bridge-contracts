// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {CommitteeRegistry} from "src/CommitteeRegistry.sol";
import {BitcoinManager} from "src/BitcoinManager.sol";
import {PegManager} from "src/PegManager.sol";
import {StreamManager} from "src/StreamManager.sol";
import {SignatureManager} from "src/SignatureManager.sol";
import {DeployImplAndProxy} from "./01_DeployImplAndProxy.s.sol";
import {SetUpStreams} from "./02_SetUpStreams.s.sol";
import {SetUpCommittees} from "./03_SetUpCommittees.s.sol";

contract DeployScript is Script {
    // Contracts to be deployed
    CommitteeRegistry public committeeRegistry;
    PegManager public pegManager;
    BitcoinManager public bitcoinManager;
    StreamManager public streamManager;
    SignatureManager public signatureManager;
    address public upgradableOwner;
    address payable public bridgeAddress;

    function setUp() internal {}

    function run() public {
        setUp();
        // deploy implementation and proxy contracts
        DeployImplAndProxy deploy = new DeployImplAndProxy();
        (committeeRegistry, bitcoinManager, pegManager, streamManager, signatureManager, upgradableOwner, bridgeAddress)
        = deploy.run();

        // Set up streams
        SetUpStreams setUpStreams = new SetUpStreams();
        setUpStreams.run(streamManager);

        SetUpCommittees setUpCommittees = new SetUpCommittees();
        // Set up streams inside committee registry
        setUpCommittees.setStreamManager(committeeRegistry, streamManager);
        // Set up committees
        setUpCommittees.run(committeeRegistry);
    }
}
