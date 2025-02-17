// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {BtcTaprootParser} from "src/libraries/BtcTaprootParser.sol";

contract TestBtcTaprootParser is Test {
    function setUp() external {}

    function test_getP2TRScriptPubKey_Success_KeyPath() external pure {
        // Arrenge
        bytes32 publicKey = 0x0908421cb37d204b0c68660d093534d50d01fa791a3313e5fd9c21da137785eb;
        bytes32 merkleRoot = bytes32(0);
        // Act
        bytes memory scriptPubKey = BtcTaprootParser.getP2TRScriptPubKey(publicKey, merkleRoot, bytes(""));
        // Assert
        assertEq(
            scriptPubKey,
            hex"5120f8bc2bbb52031daee28da58481e8ec3b045202ed9213b62bf33e221d31b3e6ef",
            "getP2TRScriptPubKey KeyPath should give the correct Script public key"
        );
    }

    function test_getP2TRScriptPubKey_Success_ScriptPath() external pure {
        // Arrenge
        // Data from https://learnmeabitcoin.com/technical/upgrades/taproot/#scriptpubkey
        bytes32 publicKey = 0xa2fc329a085d8cfc4fa28795993d7b666cee024e94c40115141b8e9be4a29fa4;
        bytes32 merkleRoot = 0xb5b72eea07b3e338962944a752a98772bbe1f1b6550e6fb6ab8c6e6adb152e7c;
        // Act
        bytes memory scriptPubKey = BtcTaprootParser.getP2TRScriptPubKey(publicKey, merkleRoot, bytes(""));
        // Assert
        assertEq(
            scriptPubKey,
            hex"5120562529047f476b9a833a5a780a75845ec32980330d76d1ac9f351dc76bce5d72",
            "getP2TRScriptPubKey ScriptPath should give the correct Script public key"
        );
    }

    function test_getLeaf_Success() external pure {
        // Arrenge
        bytes memory script = hex"5187";
        // Act
        bytes32 leafHash = BtcTaprootParser.getLeaf(script);
        // Assert
        assertEq(
            leafHash,
            0x6b13becdaf0eee497e2f304adcfa1c0c9e84561c9989b7f2b5fc39f5f90a60f6,
            "getLeaf should give the correct tagged hash"
        );
    }

    function test_getBranch_Success() external pure {
        // Arrenge
        // https://learnmeabitcoin.com/technical/upgrades/taproot/#script-tree-merkle-root-branch-hash
        bytes32 leafHash1 = 0x6b13becdaf0eee497e2f304adcfa1c0c9e84561c9989b7f2b5fc39f5f90a60f6;
        bytes32 leafHash2 = 0xed5af8352e2a54cce8d3ea326beb7907efa850bdfe3711cef9060c7bb5bcf59e;
        bytes32 leafHash3 = 0x160bd30406f8d5333be044e6d2d14624470495da8a3f91242ce338599b233931;
        bytes32 leafHash4 = 0xbf2c4bf1ca72f7b8538e9df9bdfd3ba4c305ad11587f12bbfafa00d58ad6051d;
        bytes32 leafHash5 = 0x54962df196af2827a86f4bde3cf7d7c1a9dcb6e17f660badefbc892309bb145f;

        // branch 1 (leaf 1 hash + leaf 2 hash) = 1324300a84045033ec539f60c70d582c48b9acf04150da091694d83171b44ec9
        bytes32 branch1 = BtcTaprootParser.getBranch(leafHash1, leafHash2);
        assertEq(
            branch1,
            0x1324300a84045033ec539f60c70d582c48b9acf04150da091694d83171b44ec9,
            "getBranch branch1 should be the correct tagged hash"
        );

        // branch 2 (branch 1 + leaf 3 hash) = beec0122bddd26f642140bcd922e0264ce1e2be5808a41ae58d82e829bc913d7
        bytes32 branch2 = BtcTaprootParser.getBranch(branch1, leafHash3);
        assertEq(
            branch2,
            0xbeec0122bddd26f642140bcd922e0264ce1e2be5808a41ae58d82e829bc913d7,
            "getBranch branch2 should be the correct tagged hash"
        );

        // branch 3 (branch 2 + leaf 4 hash)    = a4e0d9cc12ce2f32069e98247581d5eb9ca0a4cf175771a8df2c53a93dcb0ebd
        bytes32 branch3 = BtcTaprootParser.getBranch(branch2, leafHash4);
        assertEq(
            branch3,
            0xa4e0d9cc12ce2f32069e98247581d5eb9ca0a4cf175771a8df2c53a93dcb0ebd,
            "getBranch branch3 should be the correct tagged hash"
        );

        // branch 4 (leaf 5 hash + branch 3)    = b5b72eea07b3e338962944a752a98772bbe1f1b6550e6fb6ab8c6e6adb152e7c
        bytes32 branch4 = BtcTaprootParser.getBranch(branch3, leafHash5);
        assertEq(
            branch4,
            0xb5b72eea07b3e338962944a752a98772bbe1f1b6550e6fb6ab8c6e6adb152e7c,
            "getBranch branch4 should be the correct tagged hash"
        );
    }
}
