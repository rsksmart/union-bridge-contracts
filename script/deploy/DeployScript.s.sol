// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {CommitteeRegistry} from "src/CommitteeRegistry.sol";
import {MemberRegistry} from "src/MemberRegistry.sol";
import {BitcoinManager} from "src/BitcoinManager.sol";
import {PegManager} from "src/PegManager.sol";
import {StreamManager} from "src/StreamManager.sol";
import {SignatureManager} from "src/SignatureManager.sol";
import {DeployImplAndProxy, DeployedContracts} from "./01_DeployImplAndProxy.s.sol";

contract DeployScript is Script {
    // Contracts to be deployed
    CommitteeRegistry public committeeRegistry;
    MemberRegistry public memberRegistry;
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
        DeployedContracts memory deployResults = deploy.run();

        committeeRegistry = deployResults.committeeRegistry;
        memberRegistry = deployResults.memberRegistry;
        bitcoinManager = deployResults.bitcoinManager;
        pegManager = deployResults.pegManager;
        streamManager = deployResults.streamManager;
        signatureManager = deployResults.signatureManager;
        upgradableOwner = deployResults.upgradableOwner;
        bridgeAddress = deployResults.bridgeAddress;
    }
}
