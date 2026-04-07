// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {console} from "forge-std/console.sol";
import {BtcTxSPVProof} from "src/interfaces/IPegCommonTypes.sol";
import {ScriptUtils} from "script/helpers/ScriptUtils.sol";
import {ContractAddressManager} from "script/helpers/ContractAddressManager.sol";
import {BtcTransaction} from "src/interfaces/IBitcoinManager.sol";
import {IOperatorTakeManager} from "src/interfaces/IOperatorTakeManager.sol";

contract RegisterAdvanceFundsScript is ScriptUtils, ContractAddressManager {
    IOperatorTakeManager operatorTakeManager;

    bytes userPubKey;
    uint64 amount;
    bytes32 expectedPegoutId;

    function setUp(bytes32 _acceptPeginTxid) internal {
        operatorTakeManager = getOperatorTakeManager();

        userPubKey = hex"02d56ad001b55eabf431e602599fcc0d7ed9d676ac93c2be11d0de6e25dd598d8b";
        amount = 100_000; // 0.001 BTC

        expectedPegoutId = operatorTakeManager.getOperatorTakeInfo(_acceptPeginTxid).pegoutId;
    }

    function run(bytes32 _acceptPeginTxid) public {
        setUp(_acceptPeginTxid);

        console.log("=== Register Advance Funds ===");

        BtcTransaction memory advanceFundsTx = createAdvanceFundsTx(userPubKey, amount, expectedPegoutId);
        BtcTxSPVProof memory advanceFundsSPV = createBtcTxSPVProof(advanceFundsTx);

        vm.startBroadcast(getDeployerKey());
        operatorTakeManager.registerAdvanceFunds(_acceptPeginTxid, advanceFundsSPV);
        vm.stopBroadcast();

        console.log("=== Advance Funds registered successfully ===");
    }
}
