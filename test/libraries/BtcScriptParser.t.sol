// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {BtcScriptParser} from "src/libraries/BtcScriptParser.sol";
import {BtcHelper} from "src/libraries/BtcHelper.sol";
import {BytesHelper} from "src/libraries/BytesHelper.sol";
import {OpCodes} from "src/libraries/OpCodes.sol";
import {TestUtils} from "test/helpers/TestUtils.sol";

contract BtcScriptParserTest is Test, TestUtils {
    bytes32 internal pubKey;

    constructor() {
        pubKey = generatePubKey(1);
    }

    function setUp() external {}

    function test_getTimelockScript_Success_OP_0() external view {
        // Arrange 1
        uint32 blocks = 0;
        // Act
        bytes memory script = BtcScriptParser.getTimelockScript(blocks, pubKey);
        // Assert
        uint256 i = 0;
        assertEq(script[i], OpCodes.OP_0, "First part should be OP_0");
        i++;
        // No second part because the number is 0
        _checkScriptAfterPushBlock(script, i, pubKey);
    }

    function test_getTimelockScript_Success_OP_PUSHNUM() external view {
        // Arrange 1
        uint32 blocks = 1;
        // Act
        bytes memory script = BtcScriptParser.getTimelockScript(blocks, pubKey);
        // Assert
        uint256 i = 0;
        assertEq(script[i], OpCodes.OP_1, "First part should be OP_PUSHBYTES_1");
        i++;
        // No second part because the number is 1-16
        _checkScriptAfterPushBlock(script, i, pubKey);

        // Arrange 16
        blocks = 16;
        // Act
        script = BtcScriptParser.getTimelockScript(blocks, pubKey);
        // Assert
        i = 0;
        assertEq(script[i], OpCodes.OP_PUSHNUM_16, "First part should be OP_PUSHBYTES_16");
        i++;
        _checkScriptAfterPushBlock(script, i, pubKey);
    }

    function test_getTimelockScript_Success_OP_PUSHBYTES1() external view {
        // Arrange 17
        uint32 blocks = 17;
        // Act
        bytes memory script = BtcScriptParser.getTimelockScript(blocks, pubKey);
        // Assert
        uint256 i = 0;
        assertEq(script[i], OpCodes.OP_PUSHBYTES_1, "First part should be OP_PUSHBYTES_1");
        i++;
        assertEq(script[i], bytes1(uint8(blocks)), "Second part should be the number of blocks");
        i++;
        _checkScriptAfterPushBlock(script, i, pubKey);

        // Arrange 127
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

    function test_getTimelockScript_Success_OP_PUSHBYTES2() external view {
        // Arrange 128
        uint32 blocks = 128;
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

        // Arrange 32767
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

    function test_getTimelockScript_Success_OP_PUSHBYTES3() external view {
        // Arrange 32768
        uint32 blocks = 32768;
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

        // Arrange 65535
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
        // Arrange
        uint32 blocks = 65536;
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

    function test_getP2WPKHScript_Success() external view {
        // Arrange
        bytes memory signedPubKey = abi.encodePacked(uint8(0x02), pubKey);
        // Act
        bytes memory script = BtcScriptParser.getP2WPKHScript(signedPubKey);
        // Assert
        uint256 i = 0;
        assertEq(script[i], OpCodes.OP_0, "getP2WPKH first part should be OP_0");
        i++;
        assertEq(script[i], OpCodes.OP_PUSHBYTES_20, "getP2WPKH second part should be OP_PUSHBYTES_20");
        i++;
        assertEq(
            bytes20(BytesHelper.bytesToAddress(script, i)),
            BtcHelper.hash160(signedPubKey),
            "getP2WPKH third part should be the Hash160 of the public key"
        );
    }

    function test_getPegoutIdScript_Success() external view {
        // Arrange
        bytes32 pegoutId = keccak256("pegout-id");
        // Act
        bytes memory script = BtcScriptParser.getPegoutIdScript(pegoutId);
        // Assert
        assertEq(script.length, 34, "getPegoutIdScript should return 1 + 1 + 32 bytes");
        uint256 opReturnIndex = 0;
        assertEq(script[opReturnIndex], OpCodes.OP_RETURN, "First byte should be OP_RETURN");
        uint256 opPushbytesIndex = 1;
        assertEq(script[opPushbytesIndex], OpCodes.OP_PUSHBYTES_32, "Second byte should be OP_PUSHBYTES_32");
        uint256 pegoutIdIndex = 2;
        assertEq(
            BytesHelper.bytesToBytes32(script, pegoutIdIndex), pegoutId, "Remaining 32 bytes should be the pegoutId"
        );
    }

    function test_getPegoutIdScript_DifferentIdsProduceDifferentScripts() external view {
        bytes32 pegoutId1 = bytes32(uint256(1));
        bytes32 pegoutId2 = bytes32(uint256(2));
        bytes memory script1 = BtcScriptParser.getPegoutIdScript(pegoutId1);
        bytes memory script2 = BtcScriptParser.getPegoutIdScript(pegoutId2);
        assertEq(script1.length, 34);
        assertEq(script2.length, 34);
        assertTrue(keccak256(script1) != keccak256(script2), "Different pegoutIds must produce different scripts");
    }
}
