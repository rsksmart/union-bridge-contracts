// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {console} from "forge-std/console.sol";
import {ScriptUtils} from "script/helpers/ScriptUtils.sol";
import {PegManager} from "src/PegManager.sol";
import {ISignatureManager, OperatorTakeData} from "src/interfaces/ISignatureManager.sol";

contract AddOperatorTakeTxHashScript is ScriptUtils {
    PegManager pegManager;
    ISignatureManager signatureManager;
    uint256 privKey;
    uint16 mnemonicIndex;
    address user;

    function setUp(uint16 _mnemonicIndex, bytes32 _acceptPeginTxHash, bytes32 _takeTxhash) internal {
        pegManager = PegManager(0x2279B7A0a67DB372996a5FaB50D91eAA73d2eBe6);
        signatureManager = ISignatureManager(pegManager.signatureManager());
        // Read args from command line / env
        if (_acceptPeginTxHash == bytes32(0)) {
            revert("ACCEPT_PEGIN_TX_HASH must be provided");
        }
        if (_takeTxhash == bytes32(0)) {
            revert("TAKE_TXHASH must be provided");
        }

        mnemonicIndex = _mnemonicIndex;
        if (mnemonicIndex > 9) {
            revert("MNEMONIC_INDEX must be between 0 and 9");
        }

        privKey = getMemberKey(uint32(mnemonicIndex));
        user = vm.addr(privKey);
    }

    function run(uint16 _mnemonicIndex, bytes32 _acceptPeginTxHash, bytes32 _takeTxhash) public {
        setUp(_mnemonicIndex, _acceptPeginTxHash, _takeTxhash);

        vm.startBroadcast(privKey);
        signatureManager.addOperatorTakeTxHash(_acceptPeginTxHash, _takeTxhash);
        vm.stopBroadcast();

        OperatorTakeData[] memory operatorTakeData = signatureManager.getOperatorTakeData(_acceptPeginTxHash);
        console.log("=== Operator take tx hash added successfully ===");
        for (uint256 i = 0; i < operatorTakeData.length; i++) {
            console.log("Operator take tx hash:");
            console.logBytes32(operatorTakeData[i].txHash);
            console.log("Operator address:");
            console.logAddress(operatorTakeData[i].memberAddress);
        }
    }
}
