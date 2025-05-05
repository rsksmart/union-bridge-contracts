// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {CommitteeRegistry} from "src/CommitteeRegistry.sol";
import {BitcoinManager} from "src/BitcoinManager.sol";
import {PegManager} from "src/PegManager.sol";
import {Stream} from "src/interfaces/IStreamManager.sol";
import {ChainIds} from "src/libraries/Network.sol";
import {ScriptUtils} from "script/helpers/ScriptUtils.sol";

///@dev We are using fundry-upgrades see https://github.com/OpenZeppelin/openzeppelin-foundry-upgrades
contract SetUpStreams is ScriptUtils {
    // Contracts to be deployed
    bytes32 public committeePubKey;

    function setUp() internal {
        // RSK Mainnet
        if (block.chainid == ChainIds.RSK_MAINNET) {
            committeePubKey = 0x924c163b385af7093440184af6fd6244936d1288cbb41cc3812286d3f83a3329;
        } else if (block.chainid == ChainIds.RSK_TESTNET) {
            // RSK Testnet
            // Obtained from transactions repository
            committeePubKey = 0xd1cfc2049322ff6ba3a88c6e17c6622308f0fb1d2910ffadb309e4116358723d;
        } else if (block.chainid == ChainIds.LOCAL) {
            // Foundry local chainid
            // Obtained from transactions repository
            committeePubKey = 0xd1cfc2049322ff6ba3a88c6e17c6622308f0fb1d2910ffadb309e4116358723d;
        } else {
            revert("Blockchain is not RSK or regtest");
        }
    }

    function run(PegManager _pegManager) public {
        setUp();
        vm.startBroadcast(getDeployerKey());
        _pegManager.createPacketsAndSlots(committeePubKey);
        vm.stopBroadcast();
        uint256 streamLen = _pegManager.getStreamsLength();
        if (streamLen == 0) {
            revert("StreamManager streams not created");
        }
        Stream memory stream = _pegManager.getStreamById(0);
        (, bytes32 packetCommitteePubKey) = _pegManager.packets(stream.streamId, stream.peginPointer);
        if (committeePubKey != packetCommitteePubKey) {
            revert("StreamManager packets not created");
        }
    }
}
