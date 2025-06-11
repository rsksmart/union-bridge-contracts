// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {PegManager} from "src/PegManager.sol";
import {CommitteeRegistry} from "src/CommitteeRegistry.sol";
import {ISignatureManager} from "src/interfaces/ISignatureManager.sol";
import {ChainIds} from "src/libraries/Network.sol";
import {BtcHelper} from "src/libraries/BtcHelper.sol";
import {ScriptUtils} from "script/helpers/ScriptUtils.sol";

contract AddEveryMemberSignatureScript is ScriptUtils {
    PegManager pegManager;
    CommitteeRegistry committeeRegistry;
    ISignatureManager signatureManager;
    bytes32 signature;
    bytes nonce;
    uint256 minCommitteMembers;
    bytes32 pegoutSignatureHash;

    function setUp() internal {
        // ====== Arguments ======
        pegManager = PegManager(0x0165878A594ca255338adfa4d48449f69242Eb8F);
        committeeRegistry = CommitteeRegistry(0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0);
        minCommitteMembers = committeeRegistry.minCommitteeMembers();
        signatureManager = pegManager.signatureManager();
        signature = hex"f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0";
        nonce =
            hex"f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a00000";

        pegoutSignatureHash = 0xbdbcc0e498ff3efd9332048959b808326e6361ba820aabdde997c49b699e8b20;
    }

    function run() public {
        setUp();
        bool allAddedNonce = false;
        console.log("=== Adding Member Nonces ===");
        for (uint8 i = 0; i < minCommitteMembers; i++) {
            if (allAddedNonce) {
                revert("Nonces should not be complete before last member");
            }
            vm.startBroadcast(getMemberKey(i));
            allAddedNonce = signatureManager.addMemberNonce(pegoutSignatureHash, nonce);
            vm.stopBroadcast();

            console.log("Added nonce for member", i);
        }
        if (!allAddedNonce) {
            revert("All nonces should be ready after last member");
        }
        console.log("=== All nonces added successfully ===");

        bool allSigned = false;
        console.log("=== Adding Member Signatures ===");
        for (uint8 i = 0; i < minCommitteMembers; i++) {
            if (allSigned) {
                revert("Signatures should not be complete before last member");
            }
            vm.startBroadcast(getMemberKey(i));
            allSigned = signatureManager.addMemberSignature(pegoutSignatureHash, signature);
            vm.stopBroadcast();

            console.log("Added signature for member", i);
        }
        if (!allSigned) {
            revert("All signatures should be ready after last member");
        }
        console.log("=== All signatures added successfully ===");
    }
}
