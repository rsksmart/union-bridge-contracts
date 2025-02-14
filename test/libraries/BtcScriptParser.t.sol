// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {BtcScriptParser} from "src/libraries/BtcScriptParser.sol";
import {BtcHelper} from "src/libraries/BtcHelper.sol";
import {BytesHelper} from "src/libraries/BytesHelper.sol";
import {OpCodes} from "src/libraries/OpCodes.sol";
import {TestUtils} from "test/helpers/TestUtils.sol";

contract TestBtcScriptParser is Test, TestUtils {
    function setUp() external {}

    function test_getLeaf_Success() external pure {
        // Arrenge
        bytes memory script = hex"5187";
        // Act
        bytes32 leafHash = BtcScriptParser.getLeaf(script);
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
        bytes32 branch1 = BtcScriptParser.getBranch(leafHash1, leafHash2);
        assertEq(
            branch1,
            0x1324300a84045033ec539f60c70d582c48b9acf04150da091694d83171b44ec9,
            "getBranch branch1 should be the correct tagged hash"
        );

        // branch 2 (branch 1 + leaf 3 hash) = beec0122bddd26f642140bcd922e0264ce1e2be5808a41ae58d82e829bc913d7
        bytes32 branch2 = BtcScriptParser.getBranch(branch1, leafHash3);
        assertEq(
            branch2,
            0xbeec0122bddd26f642140bcd922e0264ce1e2be5808a41ae58d82e829bc913d7,
            "getBranch branch2 should be the correct tagged hash"
        );

        // branch 3 (branch 2 + leaf 4 hash)    = a4e0d9cc12ce2f32069e98247581d5eb9ca0a4cf175771a8df2c53a93dcb0ebd
        bytes32 branch3 = BtcScriptParser.getBranch(branch2, leafHash4);
        assertEq(
            branch3,
            0xa4e0d9cc12ce2f32069e98247581d5eb9ca0a4cf175771a8df2c53a93dcb0ebd,
            "getBranch branch3 should be the correct tagged hash"
        );

        // branch 4 (leaf 5 hash + branch 3)    = b5b72eea07b3e338962944a752a98772bbe1f1b6550e6fb6ab8c6e6adb152e7c
        bytes32 branch4 = BtcScriptParser.getBranch(branch3, leafHash5);
        assertEq(
            branch4,
            0xb5b72eea07b3e338962944a752a98772bbe1f1b6550e6fb6ab8c6e6adb152e7c,
            "getBranch branch4 should be the correct tagged hash"
        );
    }

    function test_getTimelockScript_Success_OP_0() external pure {
        // Arrenge 1
        uint32 blocks = 0;
        bytes32 pubKey = generatePubKey(1);
        // Act
        bytes memory script = BtcScriptParser.getTimelockScript(blocks, pubKey);
        // Assert
        uint256 i = 0;
        assertEq(script[i], OpCodes.OP_0, "First part should be OP_0");
        i++;
        // No second part because the number is 0
        _checkScriptAfterPushBlock(script, i, pubKey);
    }

    function test_getTimelockScript_Success_OP_PUSHNUM() external pure {
        // Arrenge 1
        uint32 blocks = 1;
        bytes32 pubKey = generatePubKey(1);
        // Act
        bytes memory script = BtcScriptParser.getTimelockScript(blocks, pubKey);
        // Assert
        uint256 i = 0;
        assertEq(script[i], OpCodes.OP_1, "First part should be OP_PUSHBYTES_1");
        i++;
        // No second part because the number is 1-16
        _checkScriptAfterPushBlock(script, i, pubKey);

        // Arrenge 16
        blocks = 16;
        // Act
        script = BtcScriptParser.getTimelockScript(blocks, pubKey);
        // Assert
        i = 0;
        assertEq(script[i], OpCodes.OP_PUSHNUM_16, "First part should be OP_PUSHBYTES_16");
        i++;
        _checkScriptAfterPushBlock(script, i, pubKey);
    }

    function test_getTimelockScript_Success_OP_PUSHBYTES1() external pure {
        // Arrenge 17
        uint32 blocks = 17;
        bytes32 pubKey = generatePubKey(1);
        // Act
        bytes memory script = BtcScriptParser.getTimelockScript(blocks, pubKey);
        // Assert
        uint256 i = 0;
        assertEq(script[i], OpCodes.OP_PUSHBYTES_1, "First part should be OP_PUSHBYTES_1");
        i++;
        assertEq(script[i], bytes1(uint8(blocks)), "Second part should be the number of blocks");
        i++;
        _checkScriptAfterPushBlock(script, i, pubKey);

        // Arrenge 127
        blocks = 127;
        // Act
        script = BtcScriptParser.getTimelockScript(blocks, pubKey);
        // Assert
        i = 0;
        assertEq(script[i], OpCodes.OP_PUSHBYTES_1, "First part should be OP_PUSHBYTES_1");
        i++;
        assertEq(script[i], bytes1(uint8(blocks)), "Second part should be the number of blocks");
        i++;
        _checkScriptAfterPushBlock(script, i, pubKey);
    }

    function test_getTimelockScript_Success_OP_PUSHBYTES2() external pure {
        // Arrenge 128
        uint32 blocks = 128;
        bytes32 pubKey = generatePubKey(1);
        // Act
        bytes memory script = BtcScriptParser.getTimelockScript(blocks, pubKey);
        // Assert
        uint256 i = 0;
        assertEq(script[i], OpCodes.OP_PUSHBYTES_2, "First part should be OP_PUSHBYTES_2");
        i++;
        assertEq(
            BytesHelper.bytesToUint16(script, i),
            BtcHelper.reverseUint16(uint16(blocks)),
            "Second part should be the number of blocks"
        );
        i += 2;
        _checkScriptAfterPushBlock(script, i, pubKey);

        // Arrenge 32767
        blocks = 32767;
        // Act
        script = BtcScriptParser.getTimelockScript(blocks, pubKey);
        // Assert
        i = 0;
        assertEq(script[i], OpCodes.OP_PUSHBYTES_2, "First part should be OP_PUSHBYTES_2");
        i++;
        assertEq(
            BytesHelper.bytesToUint16(script, i),
            BtcHelper.reverseUint16(uint16(blocks)),
            "Second part should be the number of blocks"
        );
        i += 2;
        _checkScriptAfterPushBlock(script, i, pubKey);
    }

    function test_getTimelockScript_Success_OP_PUSHBYTES3() external pure {
        // Arrenge 32768
        uint32 blocks = 32768;
        bytes32 pubKey = generatePubKey(1);
        // Act
        bytes memory script = BtcScriptParser.getTimelockScript(blocks, pubKey);
        // Assert
        uint256 i = 0;
        assertEq(script[i], OpCodes.OP_PUSHBYTES_3, "First part should be OP_PUSHBYTES_3");
        i++;
        assertEq(
            BytesHelper.bytesToUint24(script, i),
            BtcHelper.reverseUint24(uint24(blocks)),
            "Second part should be the number of blocks"
        );
        i += 3;
        _checkScriptAfterPushBlock(script, i, pubKey);

        // Arrenge 65535
        blocks = 65535;
        // Act
        script = BtcScriptParser.getTimelockScript(blocks, pubKey);
        // Assert
        i = 0;
        assertEq(script[i], OpCodes.OP_PUSHBYTES_3, "First part should be OP_PUSHBYTES_3");
        i++;
        assertEq(
            BytesHelper.bytesToUint24(script, i),
            BtcHelper.reverseUint24(uint24(blocks)),
            "Second part should be the number of blocks"
        );
        i += 3;
        _checkScriptAfterPushBlock(script, i, pubKey);
    }

    function test_getTimelockScript_Error_NumberTooLarge() external {
        // Arrenge
        uint32 blocks = 65536;
        bytes32 pubKey = generatePubKey(1);
        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(BtcScriptParser.NumberTooLarge.selector, blocks, BtcScriptParser.MAX_BLOCK_TIMELOCK)
        );
        // Act
        BtcScriptParser.getTimelockScript(blocks, pubKey);
    }

    function _checkScriptAfterPushBlock(bytes memory _script, uint256 _indexAfterPushBlock, bytes32 _pubKey)
        internal
        pure
    {
        assertEq(_script.length, _indexAfterPushBlock + 36, "getTimelockScript incorrect script length");
        uint256 i = _indexAfterPushBlock;
        assertEq(_script[i], OpCodes.OP_CHECKSEQUENCEVERIFY, "Third byte should be OP_CHECKSEQUENCEVERIFY");
        i++;
        assertEq(_script[i], OpCodes.OP_DROP, "Fourth part should be OP_DROP");
        i++;
        assertEq(_script[i], OpCodes.OP_PUSHBYTES_32, "Fifth part should be OP_PUSHBYTES_32");
        i++;
        assertEq(BytesHelper.bytesToBytes32(_script, i), _pubKey, "Sixth part should get the public key");
        i += 32;
        assertEq(_script[i], OpCodes.OP_CHECKSIG, "Seventh part should be OP_CHECKSIG");
    }
}
