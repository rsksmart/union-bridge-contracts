// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {BtcHelper} from "src/libraries/BtcHelper.sol";

contract TestBtcHelper is Test {
    function setUp() external {}

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

    function test_hash160_Success_PublicKey() external pure {
        // Arrenge
        // Obtained from https://learnmeabitcoin.com/technical/script/p2wpkh/#public-key-tool
        bytes32 publicKey = 0xd884657576723ed4336ae8fb82e562bc15d21effe3cef1ff550cfe5fd4d8dc90;
        // Act
        bytes20 obtainedHash160 = BtcHelper.hash160(abi.encodePacked(publicKey));
        // Assert
        assertEq(
            bytes32(obtainedHash160),
            bytes32(hex"d61e0C9A022CE199C978027e2Fa2718EAa8381db"),
            "Hashing the public key with Hash160 should give the correct hash"
        );
    }
}
