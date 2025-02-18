// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {HelperContract} from "./helpers/HelperContract.sol";
import {BitcoinManager} from "src/BitcoinManager.sol";
import {BtcTxIn, BtcTxOut, BtcTransaction} from "src/interfaces/IBitcoinManager.sol";

contract TestBtcHelper is Test, HelperContract {
    function setUp() external {
        bitcoinManager = new BitcoinManager();
    }

    function test_getBtcTxHash_Success() external view {
        // Arrenge
        BtcTransaction memory btcTx = getBtcPegInRequestTx();
        // Act
        bytes32 txHash = bitcoinManager.getBtcTxHash(btcTx);
        // Assert
        assertEq(
            txHash,
            getExpectedPegInRequestTxHash(),
            "Hashing the Transaction without the witness with Hash256 should give the correct txId"
        );
    }

    function test_getPegInOpReturnData_Success() external view {
        // Arrenge
        BtcTxOut memory btcTxOut = getBtcOPReturnOut();
        // Act
        (uint64 packetNumber, address rskDestinationAddress, bytes32 btcReimbursementPubKey) =
            bitcoinManager.getPegInOpReturnData(btcTxOut);
        // Assert
        assertEq(packetNumber, getBtcOPReturnPacket(), "OP_RETURN packet number should be correct  ");
        assertEq(
            rskDestinationAddress,
            getBtcOPReturnDestinationAddress(),
            "OP_RETURN RSK destination address should be correct"
        );
        assertEq(
            btcReimbursementPubKey,
            getBtcOPReturnReimbursementPubKey(),
            "OP_RETURNBTC reimbursement public key should be correct"
        );
    }
}
