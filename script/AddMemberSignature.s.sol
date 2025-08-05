// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {console} from "forge-std/console.sol";
import {PegManager} from "src/PegManager.sol";
import {ISignatureManager} from "src/interfaces/ISignatureManager.sol";
import {ScriptUtils} from "script/helpers/ScriptUtils.sol";

contract AddMemberSignature is ScriptUtils {
    PegManager pegManager;
    ISignatureManager signatureManager;
    bytes32 signature;
    bytes32 signatureHash;
    uint256 privKey;

    function setUp(uint16 _mnemonicIndex, bytes32 _signatureHash, bytes32 _signature) internal {
        // ====== Arguments ======
        pegManager = PegManager(0x0165878A594ca255338adfa4d48449f69242Eb8F);
        signatureManager = pegManager.signatureManager();

        // Read args from command line / env
        if (_mnemonicIndex > 9) {
            revert("mnemonic index must be between 0 and 9");
        }
        privKey = getMemberKey(uint32(_mnemonicIndex));

        if (_signature == bytes32(0)) {
            revert("Signature must not be zero");
        }
        signature = _signature;

        if (_signatureHash == bytes32(0)) {
            revert("Signature hash must not be zero");
        }
        signatureHash = _signatureHash;
    }

    function run(uint16 _mnemonicIndex, bytes32 _signatureHash, bytes32 _signature) public {
        setUp(_mnemonicIndex, _signatureHash, _signature);

        console.log("=== Adding Member Signature ===");
        vm.startBroadcast(privKey);
        bool signaturesReady = signatureManager.addMemberSignature(signatureHash, signature);
        vm.stopBroadcast();

        if (signaturesReady) {
            console.log("=== All signatures added successfully ===");
        } else {
            console.log("=== There are still missing signatures ===");
        }
    }
}
