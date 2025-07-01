// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {ScriptUtils} from "script/helpers/ScriptUtils.sol";
import {
    ICommitteeRegistry,
    Role,
    PublicKeyRegistration,
    PUBLIC_KEYS_INDEX_LENGTH,
    Role
} from "src/interfaces/ICommitteeRegistry.sol";
import {StreamDenomination, IStreamManager} from "src/interfaces/IStreamManager.sol";
import {PegManager} from "src/PegManager.sol";

contract ApplyToStreamScript is ScriptUtils {
    ICommitteeRegistry committeeRegistry;
    PegManager pegManager;
    IStreamManager streamManager;
    uint256 minimumDeposit;
    uint256 mnemonicIndex;
    uint256 streamId;
    uint256 role;
    uint256 privKey;
    address user;
    PublicKeyRegistration[] pubKeysRegistration;

    function setUp(uint16 _mnemonicIndex, uint16 _streamIndex, uint16 _roleIndex) internal {
        committeeRegistry = ICommitteeRegistry(0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0);
        pegManager = PegManager(0x0165878A594ca255338adfa4d48449f69242Eb8F);
        streamManager = IStreamManager(pegManager.streamManager());
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

        minimumDeposit = streamManager.getMinimumDeposit(StreamDenomination(streamId), Role(role));
        privKey = getMemberKey(uint32(mnemonicIndex));
        user = vm.addr(privKey);
        PublicKeyRegistration[] memory pubKeysRegistrationMemory = generatePublicKeysRegistration(privKey);
        for (uint8 i = 0; i < PUBLIC_KEYS_INDEX_LENGTH; i++) {
            pubKeysRegistration.push(pubKeysRegistrationMemory[i]);
        }

        if (user.balance < minimumDeposit) {
            revert("Insufficient balance to apply to stream");
        }
    }

    function run(uint16 _mnemonicIndex, uint16 _streamIndex, uint16 _roleIndex) public {
        setUp(_mnemonicIndex, _streamIndex, _roleIndex);

        vm.startBroadcast(privKey);
        committeeRegistry.applyToStream{value: minimumDeposit}(
            StreamDenomination(streamId), Role(role), pubKeysRegistration
        );
        vm.stopBroadcast();
        bytes32[] memory memberPubKeys = committeeRegistry.getMemberPublicKeys(user);
        for (uint8 i = 0; i < PUBLIC_KEYS_INDEX_LENGTH; i++) {
            if (memberPubKeys[i] != pubKeysRegistration[i].publicKeyX) {
                revert("applyToStream failed: public key mismatch");
            }
        }

        console.log("=== User applied to stream successfully ===");
        console.log("Mnemonic Index:", mnemonicIndex);
        console.log("User:", user);
        console.log("Stream:", streamId);
        console.log("Role:", role);
        console.log("Deposit:", minimumDeposit);
    }
}
