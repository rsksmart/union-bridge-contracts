// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {console} from "forge-std/console.sol";
import {PegManager} from "src/PegManager.sol";
import {ISignatureManager} from "src/interfaces/ISignatureManager.sol";
import {ScriptUtils} from "script/helpers/ScriptUtils.sol";
import {ContractAddressManager} from "script/helpers/ContractAddressManager.sol";

contract AddMemberSignature is ScriptUtils, ContractAddressManager {
    PegManager pegManager;
    ISignatureManager signatureManager;
    bytes32 signature;
    bytes32 txid;
    uint256 privKey;

    function setUp(uint16 _mnemonicIndex, bytes32 _txid, bytes32 _signature) internal {
        // ====== Arguments ======
        pegManager = PegManager(getPegManager());
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

        if (_txid == bytes32(0)) {
            revert("Transaction id must not be zero");
        }
        txid = _txid;
    }

    function run(uint16 _mnemonicIndex, bytes32 _txid, bytes32 _signature) public {
        setUp(_mnemonicIndex, _txid, _signature);

        console.log("=== Adding Member Signature ===");
        vm.startBroadcast(privKey);
        bool signaturesReady = signatureManager.addMemberSignature(txid, signature);
        vm.stopBroadcast();

        if (signaturesReady) {
            console.log("=== All signatures added successfully ===");
        } else {
            console.log("=== There are still missing signatures ===");
        }
    }
}
