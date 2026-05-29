// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {console} from "forge-std/console.sol";
import {PegoutManager} from "src/PegoutManager.sol";
import {ISignatureManager} from "src/interfaces/ISignatureManager.sol";
import {ScriptUtils} from "script/helpers/ScriptUtils.sol";
import {ContractAddressManager} from "script/helpers/ContractAddressManager.sol";

contract AddMemberNonce is ScriptUtils, ContractAddressManager {
    PegoutManager pegoutManager;
    ISignatureManager signatureManager;
    bytes nonce;
    bytes32 txid;
    uint256 privKey;
    address user;

    function setUp(uint16 _mnemonicIndex, bytes32 _txid, bytes memory _nonce) internal {
        pegoutManager = PegoutManager(getPegoutManager());
        signatureManager = pegoutManager.signatureManager();

        // Read args from command line / env
        if (_mnemonicIndex > 9) {
            revert("mnemonic index must be between 0 and 9");
        }
        privKey = getMemberKey(uint32(_mnemonicIndex));

        // FIXME: is this needed?
        user = vm.addr(privKey);

        if (_nonce.length != 66) {
            revert("Nonce must be 66 bytes long");
        }
        nonce = _nonce;

        if (_txid == bytes32(0)) {
            revert("Transaction id must not be zero");
        }
        txid = _txid;
    }

    function run(uint16 _mnemonicIndex, bytes32 _txid, bytes memory _nonce) public {
        setUp(_mnemonicIndex, _txid, _nonce);

        console.log("=== Adding Member Nonce ===");
        vm.startBroadcast(privKey);
        bool noncesReady = signatureManager.addMemberNonce(txid, _nonce);
        vm.stopBroadcast();

        if (noncesReady) {
            console.log("=== All nonces added successfully ===");
        } else {
            console.log("=== There are still missing nonces ===");
        }
    }
}
