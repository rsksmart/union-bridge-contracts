// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {CommitteeRegistry} from "src/CommitteeRegistry.sol";
import {MemberRegistry} from "src/MemberRegistry.sol";
import {BitcoinManager} from "src/BitcoinManager.sol";
import {PeginManager} from "src/PeginManager.sol";
import {PegoutManager} from "src/PegoutManager.sol";
import {StreamManager} from "src/StreamManager.sol";
import {SignatureManager} from "src/SignatureManager.sol";
import {AccessManager} from "src/AccessManager.sol";
import {RbtcBridge} from "src/RbtcBridge.sol";
import {ChallengeManager} from "src/ChallengeManager.sol";
import {OperatorTakeManager} from "src/OperatorTakeManager.sol";
import {DeployImplAndProxy, DeployedContracts} from "./01_DeployImplAndProxy.s.sol";

contract DeployScript is Script {
    // Contracts to be deployed
    CommitteeRegistry public committeeRegistry;
    MemberRegistry public memberRegistry;
    BitcoinManager public bitcoinManager;
    RbtcBridge public rbtcBridge;
    PeginManager public peginManager;
    PegoutManager public pegoutManager;
    StreamManager public streamManager;
    SignatureManager public signatureManager;
    AccessManager public accessManager;
    ChallengeManager public challengeManager;
    OperatorTakeManager public operatorTakeManager;
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
        rbtcBridge = deployResults.rbtcBridge;
        peginManager = deployResults.peginManager;
        pegoutManager = deployResults.pegoutManager;
        streamManager = deployResults.streamManager;
        signatureManager = deployResults.signatureManager;
        accessManager = deployResults.accessManager;
        upgradableOwner = deployResults.upgradableOwner;
        bridgeAddress = deployResults.bridgeAddress;
        challengeManager = deployResults.challengeManager;
        operatorTakeManager = deployResults.operatorTakeManager;
    }
}
