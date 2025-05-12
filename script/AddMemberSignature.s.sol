// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {PegManager} from "src/PegManager.sol";
import {ChainIds} from "src/libraries/Network.sol";
import {BtcHelper} from "src/libraries/BtcHelper.sol";
import {ScriptUtils} from "script/helpers/ScriptUtils.sol";

contract AddMemberSignatureScript is ScriptUtils {
    PegManager pegManager;
    bytes32 signature;
    bytes nonce;
    bytes32 pegOutSignatureHash;

    function setUp() internal {
        // ====== Arguments ======
        pegManager = PegManager(0x0165878A594ca255338adfa4d48449f69242Eb8F);
        signature = hex"f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0";
        nonce =
            hex"f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a00000";

        pegOutSignatureHash = 0xbdbcc0e498ff3efd9332048959b808326e6361ba820aabdde997c49b699e8b20;
    }

    function run() public {
        setUp();

        console.log("=== Add First Member Signature to Signature Hash ===");

        vm.startBroadcast(getMemberKey(0));
        bool allSigned = pegManager.addMemberSignature(pegOutSignatureHash, signature, nonce);
        vm.stopBroadcast();

        if (allSigned == true) {
            revert("All signatures should not be ready at this point");
        }

        console.log("=== Addeded First Member Signature successfully ===");

        console.log("=== Add Second Member Signature to Signature Hash ===");
        vm.startBroadcast(getMemberKey(1));
        allSigned = pegManager.addMemberSignature(pegOutSignatureHash, signature, nonce);
        vm.stopBroadcast();

        if (allSigned == false) {
            revert("All signatures should be ready at this point");
        }

        console.log("=== Addeded Second Member Signature successfully ===");
        console.log("=== All signatures were added ===");
    }
}
