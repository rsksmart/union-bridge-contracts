// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {console} from "forge-std/console.sol";
import {ScriptUtils} from "script/helpers/ScriptUtils.sol";
import {ContractAddressManager} from "script/helpers/ContractAddressManager.sol";
import {PegoutManager} from "src/PegoutManager.sol";
import {ISignatureManager, OperatorTakeData} from "src/interfaces/ISignatureManager.sol";

contract addOperatorTakeTxidsScript is ScriptUtils, ContractAddressManager {
    PegoutManager pegoutManager;
    ISignatureManager signatureManager;
    uint256 privKey;
    uint16 mnemonicIndex;
    address user;

    function setUp(uint16 _mnemonicIndex, bytes32 _acceptPeginTxid, bytes32 _takeTxid, bytes32 _wonTxid) internal {
        pegoutManager = PegoutManager(getPegoutManager());
        signatureManager = ISignatureManager(pegoutManager.signatureManager());
        // Read args from command line / env
        if (_acceptPeginTxid == bytes32(0)) {
            revert("ACCEPT_PEGIN_TXID must be provided");
        }
        if (_takeTxid == bytes32(0)) {
            revert("TAKE_TXID must be provided");
        }
        if (_wonTxid == bytes32(0)) {
            revert("WON_TXID must be provided");
        }

        mnemonicIndex = _mnemonicIndex;
        if (mnemonicIndex > 9) {
            revert("MNEMONIC_INDEX must be between 0 and 9");
        }

        privKey = getMemberKey(uint32(mnemonicIndex));
        user = vm.addr(privKey);
    }

    function run(uint16 _mnemonicIndex, bytes32 _acceptPeginTxid, bytes32 _takeTxid, bytes32 _wonTxid) public {
        setUp(_mnemonicIndex, _acceptPeginTxid, _takeTxid, _wonTxid);

        vm.startBroadcast(privKey);
        signatureManager.addOperatorTakeTxids(_acceptPeginTxid, _takeTxid, _wonTxid);
        vm.stopBroadcast();

        OperatorTakeData[] memory operatorTakeData = signatureManager.getOperatorTakeData(_acceptPeginTxid);
        console.log("=== Operator take tx id added successfully ===");
        for (uint256 i = 0; i < operatorTakeData.length; i++) {
            console.log("Operator take tx id:");
            console.logBytes32(operatorTakeData[i].takeTxid);
            console.log("Operator won tx id:");
            console.logBytes32(operatorTakeData[i].wonTxid);
            console.log("Operator address:");
            console.logAddress(operatorTakeData[i].memberAddress);
        }
    }
}
