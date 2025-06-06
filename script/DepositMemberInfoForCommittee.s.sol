// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {ScriptUtils} from "script/helpers/ScriptUtils.sol";
import {ICommitteeRegistry, Role} from "src/interfaces/ICommitteeRegistry.sol";
// import {StreamDenomination} from "src/interfaces/IStreamManager.sol";

contract DepositMemberInfoForCommitteeScript is ScriptUtils {
    ICommitteeRegistry committeeRegistry;

    bytes32 committeePubKey;
    uint16 mnemonicIndex;
    uint64 stream;
    uint256 privKey;
    address user;
    bytes32 pubKey;

    function setUp(uint16 _mnemonicIndex, uint64 _streamIndex, bytes32 _committeePubKey) internal {
        committeeRegistry = ICommitteeRegistry(0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0);

        // Read args from command line / env
        mnemonicIndex = _mnemonicIndex;
        if (mnemonicIndex > 9) {
            revert("mnemonic index must be between 0 and 9");
        }
        stream = _streamIndex;
        if (stream > 4) {
            revert("stream index must be between 0 and 4");
        }
        committeePubKey = _committeePubKey;
        if (committeePubKey == bytes32(0)) {
            revert("committee pub key must be provided");
        }

        privKey = getMemberKey(uint32(mnemonicIndex));
        user = vm.addr(privKey);
    }

    function run(uint16 _mnemonicIndex, uint64 _streamIndex, bytes32 _committeePubKey) public {
        setUp(_mnemonicIndex, _streamIndex, _committeePubKey);

        vm.startBroadcast(privKey);
        committeeRegistry.depositMemberInfoForCommittee(stream, committeePubKey);
        vm.stopBroadcast();

        console.log("=== User deposited info for committee successfully ===");
        console.log("Mnemonic Index:", mnemonicIndex);
        console.log("User:", user);
        console.log("Stream:", stream);
        console.log("Info:");
        console.logBytes32(committeePubKey);
    }
}
