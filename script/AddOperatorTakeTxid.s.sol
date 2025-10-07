// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {console} from "forge-std/console.sol";
import {ScriptUtils} from "script/helpers/ScriptUtils.sol";
import {PegManager} from "src/PegManager.sol";
import {ISignatureManager, OperatorTakeData} from "src/interfaces/ISignatureManager.sol";

contract AddOperatorTakeTxidScript is ScriptUtils {
    PegManager pegManager;
    ISignatureManager signatureManager;
    uint256 privKey;
    uint16 mnemonicIndex;
    address user;

    function setUp(uint16 _mnemonicIndex, bytes32 _acceptPeginTxHash, bytes32 _takeTxhash) internal {
        pegManager = getPegManagerAddress();
        signatureManager = pegManager.signatureManager();
        // Read args from command line / env
        if (_acceptPeginTxid == bytes32(0)) {
            revert("ACCEPT_PEGIN_TXID must be provided");
        }
        if (_takeTxid == bytes32(0)) {
            revert("TAKE_TXID must be provided");
        }

        mnemonicIndex = _mnemonicIndex;
        if (mnemonicIndex > 9) {
            revert("MNEMONIC_INDEX must be between 0 and 9");
        }

        privKey = getMemberKey(uint32(mnemonicIndex));
        user = vm.addr(privKey);
    }

    function run(uint16 _mnemonicIndex, bytes32 _acceptPeginTxid, bytes32 _takeTxid) public {
        setUp(_mnemonicIndex, _acceptPeginTxid, _takeTxid);

        vm.startBroadcast(privKey);
        signatureManager.addOperatorTakeTxid(_acceptPeginTxid, _takeTxid);
        vm.stopBroadcast();

        OperatorTakeData[] memory operatorTakeData = signatureManager.getOperatorTakeData(_acceptPeginTxid);
        console.log("=== Operator take tx id added successfully ===");
        for (uint256 i = 0; i < operatorTakeData.length; i++) {
            console.log("Operator take tx id:");
            console.logBytes32(operatorTakeData[i].txid);
            console.log("Operator address:");
            console.logAddress(operatorTakeData[i].memberAddress);
        }
    }
}
