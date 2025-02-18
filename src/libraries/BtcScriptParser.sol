// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {OpCodes} from "./OpCodes.sol";
import {BtcHelper} from "./BtcHelper.sol";

/**
 * @title Bitcoin Script Parser
 * @notice Allows to encode / decode Bitcoin Scripts
 * @author Fairgate
 */
library BtcScriptParser {
    uint256 constant MAX_BLOCK_TIMELOCK = 65535;
    // Errors

    error NumberTooLarge(uint256 actual, uint256 max);

    function getP2WPKHScript(bytes32 _publicKey) internal pure returns (bytes memory) {
        // Pay To Witness Public Key Hash
        return abi.encodePacked(OpCodes.OP_0, OpCodes.OP_PUSHBYTES_20, _publicKey);
    }

    function pushNumberToStack(uint256 _number) internal pure returns (bytes memory) {
        if (_number == 0) {
            return abi.encodePacked(OpCodes.OP_0);
        } else if (_number <= 16) {
            // 1 - 16
            // only push opcode from OP_PUSHNUM_1 up to OP_PUSHNUM_16
            return abi.encodePacked(bytes1(uint8(OpCodes.OP_1) + uint8(_number - 1)));
        } else if (_number <= 127) {
            // 17 - 127
            // push the number as a single byte
            return abi.encodePacked(OpCodes.OP_PUSHBYTES_1, bytes1(uint8(_number)));
        } else if (_number <= 32767) {
            // 128 - 32767
            // push the number as a 2-byte sequence
            return abi.encodePacked(OpCodes.OP_PUSHBYTES_2, BtcHelper.reverseUint16((uint16(_number))));
        } else if (_number <= 65535) {
            // 32768 - 65535
            // push the number as a 3-byte sequence
            return abi.encodePacked(OpCodes.OP_PUSHBYTES_3, BtcHelper.reverseUint24(uint24(_number)));
        } else if (_number <= 2147483647) {
            // 65536 - 2147483647
            // push the number as a 4-byte sequence
            return abi.encodePacked(OpCodes.OP_PUSHBYTES_4, BtcHelper.reverseUint32(uint32(_number)));
        }
        revert NumberTooLarge(_number, 2147483647);
    }

    function getTimelockScript(uint32 _blocks, bytes32 _publicKey) internal pure returns (bytes memory) {
        if (_blocks > MAX_BLOCK_TIMELOCK) {
            revert NumberTooLarge(_blocks, MAX_BLOCK_TIMELOCK);
        }
        // If _blocks number have passed since this transaction has been confirmed,
        // the timelocked public key can spend the funds
        return abi.encodePacked(
            pushNumberToStack(_blocks),
            OpCodes.OP_CHECKSEQUENCEVERIFY, // OP_CSV
            OpCodes.OP_DROP,
            OpCodes.OP_PUSHBYTES_32,
            _publicKey, // public key is the 32-byte x-coordinate only.
            OpCodes.OP_CHECKSIG
        );
    }
}
