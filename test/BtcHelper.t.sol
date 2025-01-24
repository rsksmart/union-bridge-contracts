// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {BtcHelper} from "src/libraries/BtcHelper.sol";
import {HelperContract} from "./HelperContract.sol";
import {BtcTxIn, BtcTxOut, BtcTransaction} from "src/interfaces/IPegManager.sol";

contract TestBtcHelper is Test {
    function setUp() external {}

    function getBtcTxIn() internal pure returns (BtcTxIn memory) {
        // Data from tx 0xc00e989a80847a9e2d3e605904ae24c097b1e5abcfa6805434ab802abfcfd079
        // https://www.blockchain.com/explorer/transactions/btc/c00e989a80847a9e2d3e605904ae24c097b1e5abcfa6805434ab802abfcfd079
        return BtcTxIn({
            txId: 0x360b81785dc7c2f40627fea364676dbb73e6276683caffd9f906b0e0bd36b3d2,
            vout: 1694,
            sequence: 4294967293,
            scriptSig: hex""
        });
    }

    function getBtcTxOut() internal pure returns (BtcTxOut memory) {
        // Data from tx 0xc00e989a80847a9e2d3e605904ae24c097b1e5abcfa6805434ab802abfcfd079
        // https://www.blockchain.com/explorer/transactions/btc/c00e989a80847a9e2d3e605904ae24c097b1e5abcfa6805434ab802abfcfd079
        return BtcTxOut({amount: 294, scriptPubKey: hex"0014d3b4045c40a133ee361f766ceae4d82398fc5058"});
    }

    function getBtcTransaction() internal pure returns (BtcTransaction memory) {
        // Data from tx 0xc00e989a80847a9e2d3e605904ae24c097b1e5abcfa6805434ab802abfcfd079
        // https://www.blockchain.com/explorer/transactions/btc/c00e989a80847a9e2d3e605904ae24c097b1e5abcfa6805434ab802abfcfd079
        BtcTxIn[] memory btcInputs = new BtcTxIn[](1);
        btcInputs[0] = getBtcTxIn();
        // Output
        BtcTxOut[] memory btcOutputs = new BtcTxOut[](1);
        btcOutputs[0] = getBtcTxOut();
        return BtcTransaction({version: 2, inputs: btcInputs, outputs: btcOutputs, locktime: 0});
    }

    function getExpectedRawTx() internal pure returns (bytes memory) {
        return
        hex"0200000001d2b336bde0b006f9d9ffca836627e673bb6d6764a3fe2706f4c2c75d78810b369e06000000fdffffff012601000000000000160014d3b4045c40a133ee361f766ceae4d82398fc505800000000";
    }

    function getExpectedTxHash() internal pure returns (bytes32) {
        return 0xc00e989a80847a9e2d3e605904ae24c097b1e5abcfa6805434ab802abfcfd079;
    }

    function test_encodeTxIn_Success() external pure {
        // Arrenge
        BtcTxIn memory btcInput = getBtcTxIn();
        // Act
        bytes memory hexTxIn = BtcHelper.encodeTxIn(btcInput.txId, btcInput.vout, btcInput.sequence, btcInput.scriptSig);
        // Assert
        assertEq(
            hexTxIn,
            hex"d2b336bde0b006f9d9ffca836627e673bb6d6764a3fe2706f4c2c75d78810b369e06000000fdffffff",
            "Encoded Segwit TxIn should be correctly formed"
        );
    }

    function test_encodeTxInputs_Success() external pure {
        // Arrenge
        BtcTransaction memory btcTx = getBtcTransaction();
        // Act
        bytes memory hexTxIn = BtcHelper.encodeTxInputs(btcTx.inputs);
        // Assert
        assertEq(
            hexTxIn,
            hex"01d2b336bde0b006f9d9ffca836627e673bb6d6764a3fe2706f4c2c75d78810b369e06000000fdffffff",
            "Encoded Segwit Vin should be correctly formed"
        );
    }

    function test_encodeTxOut_Success() external pure {
        // Arrenge
        BtcTxOut memory btcOutput = getBtcTxOut();
        // Act
        bytes memory hexTxOut = BtcHelper.encodeTxOut(btcOutput.amount, btcOutput.scriptPubKey);
        // Assert
        assertEq(
            hexTxOut,
            hex"2601000000000000160014d3b4045c40a133ee361f766ceae4d82398fc5058",
            "Encoded Segwit TxOut should be correctly formed"
        );
    }

    function test_encodeTxOutputs_Success() external pure {
        // Arrenge
        BtcTransaction memory btcTx = getBtcTransaction();
        // Act
        bytes memory hexTxIn = BtcHelper.encodeTxOutputs(btcTx.outputs);
        // Assert
        assertEq(
            hexTxIn,
            hex"012601000000000000160014d3b4045c40a133ee361f766ceae4d82398fc5058",
            "Encoded Vout should be correctly formed"
        );
    }

    function test_encodeTx_Success() external pure {
        // Arrenge
        BtcTransaction memory btcTx = getBtcTransaction();
        // Act
        bytes memory hexTxIn = BtcHelper.encodeTx(btcTx);
        // Assert
        assertEq(hexTxIn, getExpectedRawTx(), "Encoded Tx should be correctly formed");
    }

    function test_reverseBytes32_Success() external pure {
        // Arrenge
        bytes32 txId = 0x360b81785dc7c2f40627fea364676dbb73e6276683caffd9f906b0e0bd36b3d2;
        // Act
        bytes32 reversedTxId = BtcHelper.reverseBytes32(txId);
        // Assert
        assertEq(
            reversedTxId,
            0xd2b336bde0b006f9d9ffca836627e673bb6d6764a3fe2706f4c2c75d78810b36,
            "Reverse should give the correct endian"
        );
    }

    function test_hash256_Success_BlockHash() external pure {
        // Arrenge
        // Obtained from Bitcoin block 879_500 using RSK precompiled bridge getBtcBlockchainBlockHeaderByHeight
        bytes memory blockBytes =
            hex"00600022bd414202c86f2e80aca72283aa584d6ee2b7597b1d6d02000000000000000000f6f5a9ccc718288b2af0c6695fec614550b3a5f4ef4c04d4116faaaa64ece1e0ac0f8967618c02173e6999e2";
        // Act
        bytes32 blockHash = BtcHelper.hash256(blockBytes);
        // Assert
        assertEq(
            blockHash,
            0x0000000000000000000282fa21665766e58eb6cb94e458c3ef6d4af1121e38d9,
            "Hashing the block with Hash256 should give the correct block hash"
        );
    }

    function test_hash256_Success_TxHash_Whithout_Witness() external pure {
        // Arrenge
        // Witness txId is the txhash but is different from wtxId https://learnmeabitcoin.com/technical/transaction/wtxid/
        // Obtained from getrawtransaction c00e989a80847a9e2d3e605904ae24c097b1e5abcfa6805434ab802abfcfd079 hex
        // https://www.quicknode.com/docs/bitcoin/getrawtransaction
        bytes memory rawTransaction = getExpectedRawTx();
        // Act
        bytes32 txHash = BtcHelper.hash256(rawTransaction);
        // Assert
        assertEq(
            txHash,
            getExpectedTxHash(),
            "Hashing the Transaction without the witness with Hash256 should give the correct txId"
        );
    }

    function test_getBtcTxHash_Success() external pure {
        // Arrenge
        BtcTransaction memory btcTx = getBtcTransaction();
        // Act
        bytes32 txHash = BtcHelper.getBtcTxHash(btcTx);
        // Assert
        assertEq(
            txHash,
            getExpectedTxHash(),
            "Hashing the Transaction without the witness with Hash256 should give the correct txId"
        );
    }
}
