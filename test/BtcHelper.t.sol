// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {BtcHelper} from "src/libraries/BtcHelper.sol";

contract TestBtcHelper is Test {
    function setUp() external {}

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
        // Non Witness txId is equal to txhash https://learnmeabitcoin.com/technical/transaction/wtxid/
        // Obtained from getrawtransaction 60183ab915f2f4b0190605f98bd0e9f8eafe13a1c902b3ae87ecd0dfc8a599a0
        // https://bitcoin.stackexchange.com/questions/108231/how-can-i-get-rawtx-transactions
        bytes memory rawTransaction =
            hex"0200000001a1565a3e50056710a250abaf55bd8b3f9bcf7ff413e23e7f8ff5d3dd25d66117020000008b483045022100ded45306a6ac022f13a16e994c87bb3f348d13e5039a5e088fe94c79e1d1ab5e0220311339632ef240d633510516c2536ae091eb176f14548412375f6f80d45e1a6b0141047146f0e0fcb3139947cf0beb870fe251930ca10d4545793d31033e801b5219abf56c11a3cf3406ca590e4c14b0dab749d20862b3adc4709153c280c2a78be10cffffffff0803170400000000001976a914817f1daf3b1080aa9d06b6969fa162b8d75a490d88ac80f773000000000017a9142c4154736c01c24d66a9e9f08df10a717e8dc81e87dbb9f4000000000017a91442771b8871e5df7baa107253c3ba156feb17db498776ecf900000000001976a9145b90ceac145472d39366f5c174e495e754e2016a88ac10037d01000000001976a9142c7c79f6a4a19b8a6071144dd9ee438d1e60c3c888ac00c2eb0b0000000017a914eade7d94aa4077025a322002a3d4f662d0bb8f1b8780fb4c2b020000001976a914d5458947802140d1ca099ef3f5b25151183e285f88ac42e3a413040000001976a91443849383122ebb8a28268a89700c9f723663b5b888ac00000000";
        // Act
        bytes32 txHash = BtcHelper.hash256(rawTransaction);
        // Assert
        assertEq(
            txHash,
            0x60183ab915f2f4b0190605f98bd0e9f8eafe13a1c902b3ae87ecd0dfc8a599a0,
            "Hashing the non witness transaction with Hash256 should give the correct txHash (txId)"
        );
    }

    // function test_hash256_Success_TxId_Whith_Witness() external pure {
    //     // Arrenge
    //     // Witness txId is different to txhash https://learnmeabitcoin.com/technical/transaction/wtxid/
    //     // Obtained from getrawtransaction c00e989a80847a9e2d3e605904ae24c097b1e5abcfa6805434ab802abfcfd079 hex
    //     // https://www.quicknode.com/docs/bitcoin/getrawtransaction
    //     bytes memory rawTransaction =
    //         hex"02000000000101d2b336bde0b006f9d9ffca836627e673bb6d6764a3fe2706f4c2c75d78810b369e06000000fdffffff012601000000000000160014d3b4045c40a133ee361f766ceae4d82398fc505803407bf29bfcee5613d2b5ad37c3a2732f3260938f00e7d2d9da5fdf80213088e25d71048c09449e4fbcca8e69cd84a04973d9b3562d114f26b9daffa6bf3929527d4420afd36e561af10735e88f95d9655e5b3f7bc79de0a4781ef99d1e030c0c567422ac0063036f7264510a746578742f706c61696e000d3837393530302e6269746d61706821c0afd36e561af10735e88f95d9655e5b3f7bc79de0a4781ef99d1e030c0c56742200000000";
    //     // Act
    //     bytes32 txHash = BtcHelper.hash256(rawTransaction);
    //     // Assert
    //     assertEq(
    //         txHash,
    //         0xc00e989a80847a9e2d3e605904ae24c097b1e5abcfa6805434ab802abfcfd079,
    //         "Hashing the Witness Transaction with Hash256 should give the correct txId"
    //     );
    // }

    function test_hash256_Success_TxHash_Whith_Witness() external view {
        // Arrenge
        // Witness txId is different to txhash https://learnmeabitcoin.com/technical/transaction/wtxid/
        // Obtained using https://bitcoin.stackexchange.com/questions/120354/how-to-compute-a-txid-of-any-bitcoin-transaction-in-python
        // first getrawtransaction c00e989a80847a9e2d3e605904ae24c097b1e5abcfa6805434ab802abfcfd079 1

        bytes memory rawTransaction =
            hex"02000000000101d2b336bde0b006f9d9ffca836627e673bb6d6764a3fe2706f4c2c75d78810b369e06000000fdffffff012601000000000000160014d3b4045c40a133ee361f766ceae4d82398fc505803407bf29bfcee5613d2b5ad37c3a2732f3260938f00e7d2d9da5fdf80213088e25d71048c09449e4fbcca8e69cd84a04973d9b3562d114f26b9daffa6bf3929527d4420afd36e561af10735e88f95d9655e5b3f7bc79de0a4781ef99d1e030c0c567422ac0063036f7264510a746578742f706c61696e000d3837393530302e6269746d61706821c0afd36e561af10735e88f95d9655e5b3f7bc79de0a4781ef99d1e030c0c56742200000000";
        // Act
        bytes32 txHash = BtcHelper.hash256(rawTransaction);
        // Assert
        assertEq(
            txHash,
            0xda7941bdccc1c040046e9b998e78a7cefec97cadc5a2f561a32afa2700598fcb,
            "Hashing the Witness Transaction with Hash256 should give the correct txHash(wTxId)"
        );
    }
}
