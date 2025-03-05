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

    /**
     * @dev Returns the Bitcoin script bytes to push a number onto the stack
     * @param _number The number to push onto the stack
     * @return The script bytes (opcodes and data) for pushing the number
     */
    function pushDataToStack(uint256 _number) internal pure returns (bytes memory) {
        // If number is 0, return OP_0 (0x00)
        if (_number == 0) {
            return hex"00";
        }

        // If number is 1-16, use OP_1 through OP_16 (0x51-0x60)
        if (_number >= 1 && _number <= 16) {
            bytes1 opcode = bytes1(uint8(0x50) + uint8(_number));
            return abi.encodePacked(opcode);
        }

        // For any other number, we need to convert it to a minimally encoded byte array
        bytes memory numberBytes = encodeMinimalNumber(_number);
        uint8 length = uint8(numberBytes.length);

        // Based on length, use appropriate PUSHDATA opcode
        if (length <= 75) {
            // Direct length byte (0x01-0x4b)
            return abi.encodePacked(bytes1(length), numberBytes);
        } else if (length <= 255) {
            // OP_PUSHDATA1 (0x4c) + 1 byte length
            return abi.encodePacked(bytes1(0x4c), bytes1(length), numberBytes);
        } else if (length <= 65535) {
            // OP_PUSHDATA2 (0x4d) + 2 byte length
            return abi.encodePacked(bytes1(0x4d), bytes2(uint16(length)), numberBytes);
        } else {
            // OP_PUSHDATA4 (0x4e) + 4 byte length
            return abi.encodePacked(bytes1(0x4e), bytes4(uint32(length)), numberBytes);
        }
    }

    /**
     * @dev Encodes a number in Bitcoin's minimal encoding format
     * In Bitcoin, numbers are stored as little-endian with the most significant bit
     * indicating the sign
     * @param _number The number to encode
     * @return Minimally encoded bytes for the number
     */
    function encodeMinimalNumber(uint256 _number) internal pure returns (bytes memory) {
        if (_number == 0) {
            return "";
        }

        // Count how many bytes we need
        uint256 tempNum = _number;
        uint256 length = 0;
        while (tempNum > 0) {
            tempNum >>= 8;
            length++;
        }

        // Add an extra byte if the highest bit of the last byte would be set
        // This prevents the number from being interpreted as negative
        if ((_number >> ((length * 8) - 1)) & 1 == 1) {
            length++;
        }

        // Create the result array with the correct length
        bytes memory result = new bytes(length);
        tempNum = _number;

        // Fill the array in little-endian order
        for (uint256 i = 0; i < length; i++) {
            result[i] = bytes1(uint8(tempNum & 0xFF));
            tempNum >>= 8;
        }

        return result;
    }
}
