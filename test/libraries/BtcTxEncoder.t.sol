// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {BtcTxEncoder} from "src/libraries/BtcTxEncoder.sol";
import {BtcTxIn, BtcTxOut, BtcTransaction} from "src/interfaces/IBitcoinManager.sol";
import {Constants} from "src/libraries/Constants.sol";

contract TestBtcTxEncoder is Test {
    function setUp() external {}

    function test_encodeTxIn_Success() external pure {
        // Arrange
        BtcTxIn memory btcInput = getRequestPeginTxIn();
        // Act
        bytes memory hexTxIn =
            BtcTxEncoder.encodeTxIn(btcInput.txId, btcInput.vout, btcInput.sequence, btcInput.scriptSig);
        // Assert
        assertEq(
            hexTxIn,
            hex"d2b336bde0b006f9d9ffca836627e673bb6d6764a3fe2706f4c2c75d78810b369e06000000fdffffff",
            "Encoded Segwit TxIn should be correctly formed"
        );
    }

    function test_encodeTxInputs_Success() external pure {
        // Arrange
        BtcTransaction memory btcTx = getBtcTransaction();
        // Act
        bytes memory hexTxIn = BtcTxEncoder.encodeTxInputs(btcTx.inputs);
        // Assert
        assertEq(
            hexTxIn,
            hex"01d2b336bde0b006f9d9ffca836627e673bb6d6764a3fe2706f4c2c75d78810b369e06000000fdffffff",
            "Encoded Segwit Vin should be correctly formed"
        );
    }

    function test_encodeTxOut_Success() external pure {
        // Arrange
        BtcTxOut memory btcOutput = getBtcTxOut();
        // Act
        bytes memory hexTxOut = BtcTxEncoder.encodeTxOut(btcOutput.amount, btcOutput.scriptPubKey);
        // Assert
        assertEq(
            hexTxOut,
            hex"2601000000000000160014d3b4045c40a133ee361f766ceae4d82398fc5058",
            "Encoded Segwit TxOut should be correctly formed"
        );
    }

    function test_encodeTxOutputs_Success() external pure {
        // Arrange
        BtcTransaction memory btcTx = getBtcTransaction();
        // Act
        bytes memory hexTxIn = BtcTxEncoder.encodeTxOutputs(btcTx.outputs);
        // Assert
        assertEq(
            hexTxIn,
            hex"012601000000000000160014d3b4045c40a133ee361f766ceae4d82398fc5058",
            "Encoded Vout should be correctly formed"
        );
    }

    function test_encodeTx_Success() external pure {
        // Arrange
        BtcTransaction memory btcTx = getBtcTransaction();
        // Act
        bytes memory hexTxIn = BtcTxEncoder.encodeTx(btcTx);
        // Assert
        assertEq(hexTxIn, getExpectedRawTx(), "Encoded Tx should be correctly formed");
    }

    function test_encodeTx_requestPegin_Success() external pure {
        // Arrange
        BtcTransaction memory btcTx =
            BtcTransaction({version: 2, inputs: new BtcTxIn[](1), outputs: new BtcTxOut[](2), locktime: 0});
        btcTx.inputs[0] = BtcTxIn({
            txId: 0xab4fc20be47cf3d862da4d9a477b3d5d0e0f3b1e54ce220e34646e7f7550f99c,
            vout: 0,
            sequence: Constants.SEQUENCE,
            scriptSig: hex""
        });
        btcTx.outputs[0] = BtcTxOut({
            amount: 100000,
            scriptPubKey: hex"5120705364e5015f051b3c85957d8e2c581c17318b50156a68c333739720d388ddfc"
        });
        btcTx.outputs[1] = BtcTxOut({
            amount: 0,
            scriptPubKey: hex"6a4552534b5f504547494e00000000000000007ac5496aee77c1ba1f0854206a26dda82a81d6d87d235c24420b2f55450c8414725aa74e6db01035245efdab0e1cfa7ab29aca0f"
        });
        // Act
        bytes memory hexTxIn = BtcTxEncoder.encodeTx(btcTx);
        // Assert
        assertEq(
            hexTxIn,
            hex"02000000019cf950757f6e64340e22ce541e3b0f0e5d3d7b479a4dda62d8f37ce40bc24fab0000000000fdffffff02a086010000000000225120705364e5015f051b3c85957d8e2c581c17318b50156a68c333739720d388ddfc0000000000000000476a4552534b5f504547494e00000000000000007ac5496aee77c1ba1f0854206a26dda82a81d6d87d235c24420b2f55450c8414725aa74e6db01035245efdab0e1cfa7ab29aca0f00000000",
            "Encoded RequestPegin Tx should be correctly formed"
        );
    }

    // Helper functions
    function getRequestPeginTxIn() internal pure returns (BtcTxIn memory) {
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
        btcInputs[0] = getRequestPeginTxIn();
        // Output
        BtcTxOut[] memory btcOutputs = new BtcTxOut[](1);
        btcOutputs[0] = getBtcTxOut();
        return BtcTransaction({version: 2, inputs: btcInputs, outputs: btcOutputs, locktime: 0});
    }

    function getExpectedRawTx() internal pure returns (bytes memory) {
        return
        hex"0200000001d2b336bde0b006f9d9ffca836627e673bb6d6764a3fe2706f4c2c75d78810b369e06000000fdffffff012601000000000000160014d3b4045c40a133ee361f766ceae4d82398fc505800000000";
    }

    function getExpectedTxid() internal pure returns (bytes32) {
        return 0xc00e989a80847a9e2d3e605904ae24c097b1e5abcfa6805434ab802abfcfd079;
    }
}
