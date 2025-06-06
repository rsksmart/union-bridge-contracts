// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {ScriptUtils} from "script/helpers/ScriptUtils.sol";
import {ICommitteeRegistry, Role} from "src/interfaces/ICommitteeRegistry.sol";
import {StreamDenomination} from "src/interfaces/IStreamManager.sol";

contract ApplyToStreamScript is ScriptUtils {
    ICommitteeRegistry committeeRegistry;
    uint256 minimumDeposit;
    uint256 mnemonicIndex;
    uint256 streamId;
    uint256 role;
    uint256 privKey;
    address user;
    bytes32 pubKey;

    function setUp(uint16 _mnemonicIndex, uint16 _streamIndex, uint16 _roleIndex) internal {
        committeeRegistry = ICommitteeRegistry(0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0);
        // Read args from command line / env
        mnemonicIndex = _mnemonicIndex;
        if (mnemonicIndex > 9) {
            revert("MNEMONIC_INDEX must be between 0 and 9");
        }
        streamId = _streamIndex;
        if (streamId > 4) {
            revert("STREAM_INDEX must be between 0 and 4");
        }
        role = _roleIndex;
        if (role > 2) {
            revert("ROLE_INDEX must be between 0 and 2");
        }

        minimumDeposit = committeeRegistry.getMinimumDeposit(StreamDenomination(streamId));
        privKey = getMemberKey(uint32(mnemonicIndex));
        user = vm.addr(privKey);
        pubKey = generatePubKeyKeccak256(privKey);

        if (user.balance < minimumDeposit) {
            revert("Insufficient balance to apply to stream");
        }
    }

    function run(uint16 _mnemonicIndex, uint16 _streamIndex, uint16 _roleIndex) public {
        setUp(_mnemonicIndex, _streamIndex, _roleIndex);

        vm.startBroadcast(privKey);
        committeeRegistry.applyToStream{value: minimumDeposit}(pubKey, StreamDenomination(streamId), Role(role));
        vm.stopBroadcast();

        if (committeeRegistry.getMemberPublicKey(user) != pubKey) {
            revert("applyToStream failed: public key mismatch");
        }

        console.log("=== User applied to stream successfully ===");
        console.log("Mnemonic Index:", mnemonicIndex);
        console.log("User:", user);
        console.log("Stream:", streamId);
        console.log("Role:", role);
        console.log("Deposit:", minimumDeposit);
    }
}
