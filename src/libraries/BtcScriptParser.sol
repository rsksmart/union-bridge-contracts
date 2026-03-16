// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {OpCodes} from "./OpCodes.sol";
import {BtcHelper} from "./BtcHelper.sol";

/// @title Bitcoin Script Parser
/// @notice Library for encoding and decoding Bitcoin scripts
/// @dev Provides functions to create various Bitcoin script types and push data to the stack
/// @dev Used for creating Bitcoin transaction scripts in the union bridge
/// @author Fairgate
library BtcScriptParser {
    /// @dev Maximum block timelock value allowed in scripts
    /// @dev Used to prevent excessive timelock values
    uint256 constant MAX_BLOCK_TIMELOCK = 65535;

    // Errors
    /// @notice Error thrown when a number exceeds the maximum allowed value
    /// @param actual The actual number value that was too large
    /// @param max The maximum allowed value
    error NumberTooLarge(uint256 actual, uint256 max);

    /// @notice Creates a Pay-to-Witness-Public-Key-Hash (P2WPKH) script
    /// @dev Creates a native SegWit script for spending to a public key hash
    /// @param _userPubKey The user's public key to hash
    /// @return The P2WPKH script bytes
    function getP2WPKHScript(bytes memory _userPubKey) internal pure returns (bytes memory) {
        bytes20 pubKeyHash = BtcHelper.hash160(_userPubKey);

        return abi.encodePacked(OpCodes.OP_0, OpCodes.OP_PUSHBYTES_20, pubKeyHash);
    }

    /// @notice Creates a Pay-to-Witness-Script-Hash (P2WSH) script
    /// @dev Creates a native SegWit script for spending to a script hash
    /// @param _script The script to hash
    /// @return The P2WSH script bytes
    function getP2WSHScript(bytes memory _script) internal pure returns (bytes memory) {
        bytes32 scriptHash = sha256(_script);

        return abi.encodePacked(OpCodes.OP_0, OpCodes.OP_PUSHBYTES_32, scriptHash);
    }

    /// @notice Creates OP_RETURN script for pegout ID (BitVMX compatible format)
    /// @dev Uses standard Bitcoin script format: OP_RETURN OP_PUSHBYTES_32 <32 bytes>
    /// @dev Matches BitVMX rust-bitvmx-client ADVANCE_FUNDS_TX output structure
    /// @param _pegoutId The 32-byte pegout identifier
    /// @return The script bytes for OP_RETURN output
    function getPegoutIdScript(bytes32 _pegoutId) internal pure returns (bytes memory) {
        return abi.encodePacked(OpCodes.OP_RETURN, OpCodes.OP_PUSHBYTES_32, _pegoutId);
    }

    /// @notice Pushes a number onto the Bitcoin script stack
    /// @dev Handles different number ranges with appropriate opcodes and encoding
    /// @dev Uses minimal encoding for numbers to optimize script size
    /// @param _number The number to push onto the stack
    /// @return The script bytes for pushing the number
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

    /// @notice Creates a timelock script with OP_CHECKSEQUENCEVERIFY
    /// @dev If the specified number of blocks have passed since transaction confirmation,
    /// @dev the timelocked public key can spend the funds
    /// @param _blocks The number of blocks to wait before the script can be spent
    /// @param _publicKey The 32-byte x-coordinate of the public key (Taproot format)
    /// @return The timelock script bytes
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
