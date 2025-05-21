// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {PegManager} from "src/PegManager.sol";
import {ISignatureManager} from "src/interfaces/ISignatureManager.sol";
import {ChainIds} from "src/libraries/Network.sol";
import {BtcHelper} from "src/libraries/BtcHelper.sol";
import {ScriptUtils} from "script/helpers/ScriptUtils.sol";

contract AddMemberSignatureScript is ScriptUtils {
    PegManager pegManager;
    ISignatureManager signatureManager;
    bytes32 signature;
    bytes nonce;
    bytes32 pegOutSignatureHash;

    function setUp() internal {
        // ====== Arguments ======
        pegManager = PegManager(0x0165878A594ca255338adfa4d48449f69242Eb8F);
        signatureManager = pegManager.signatureManager();
        signature = hex"f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0";
        nonce =
            hex"f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a00000";

        pegOutSignatureHash = 0xbdbcc0e498ff3efd9332048959b808326e6361ba820aabdde997c49b699e8b20;
    }

    function run() public {
        setUp();

        console.log("=== Add First Member Nonce to Signature Hash ===");

        vm.startBroadcast(getMemberKey(0));
        bool allAddedNonce = signatureManager.addMemberNonce(pegOutSignatureHash, nonce);
        vm.stopBroadcast();

        if (allAddedNonce == true) {
            revert("All nonces should not be ready at this point");
        }

        console.log("=== Addeded First Member Nonce successfully ===");

        console.log("=== Add Second Member Nonce to Signature Hash ===");
        vm.startBroadcast(getMemberKey(1));
        allAddedNonce = signatureManager.addMemberNonce(pegOutSignatureHash, nonce);
        vm.stopBroadcast();

        if (allAddedNonce == false) {
            revert("All nonces should be ready at this point");
        }

        console.log("=== Addeded Second Member Nonce successfully ===");
        console.log("=== All nonces were added ===");

        console.log("=== Add First Member Signature to Signature Hash ===");

        vm.startBroadcast(getMemberKey(0));
        bool allSigned = signatureManager.addMemberSignature(pegOutSignatureHash, signature);
        vm.stopBroadcast();

        if (allSigned == true) {
            revert("All signatures should not be ready at this point");
        }

        console.log("=== Addeded First Member Signature successfully ===");

        console.log("=== Add Second Member Signature to Signature Hash ===");
        vm.startBroadcast(getMemberKey(1));
        allSigned = signatureManager.addMemberSignature(pegOutSignatureHash, signature);
        vm.stopBroadcast();

        if (allSigned == false) {
            revert("All signatures should be ready at this point");
        }

        console.log("=== Addeded Second Member Signature successfully ===");
        console.log("=== All signatures were added ===");
    }
}
