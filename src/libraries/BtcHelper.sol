// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {Constants} from "./Constants.sol";
/**
 * @title Btc Helper
 * @notice Usefull functions for Bitcoin parsin/encoding/decoding
 * @author Fairgate
 */

library BtcHelper {
    /// @notice Converts a size value to Bitcoin's compact size format
    /// @dev The first byte indicates which bytes encode the integer:
    /// @dev <= FC – This byte (0 - 252)
    /// @dev FD – The next two bytes (253 - 65535)
    /// @dev FE – The next four bytes (65536 - 4294967295)
    /// @dev FF – The next eight bytes (4294967296 - 18446744073709551615)
    /// @dev Note: Bytes encoding the integer are in little endian
    /// @dev See: https://learnmeabitcoin.com/technical/general/compact-_size/
    /// @param _size The size value to convert
    /// @return The compact size encoded bytes
    function toCompactSize(uint256 _size) internal pure returns (bytes memory) {
        if (_size <= 252) {
            return abi.encodePacked(uint8(_size));
        } else if (_size <= 65535) {
            return abi.encodePacked(uint8(0xFD), BtcHelper.reverseUint16(uint16(_size)));
        } else if (_size <= 4294967295) {
            return abi.encodePacked(uint8(0xFE), BtcHelper.reverseUint32(uint32(_size)));
        }
        return abi.encodePacked(uint8(0xFF), BtcHelper.reverseUint64(uint64(_size)));
    }

    /// @notice Implements Bitcoin's hash160 (RIPEMD160(SHA256()))
    /// @dev abi.encodePacked changes the return to bytes instead of bytes32
    /// @dev Used for creating Bitcoin addresses from public keys
    /// @param _b The pre-image to hash
    /// @return The RIPEMD160(SHA256()) digest
    /// @dev See: https://github.com/bob-collective/bitcoin-spv/blob/master/src/BTCUtils.sol#L192C5-L198C6
    function hash160(bytes memory _b) internal pure returns (bytes20) {
        return ripemd160(abi.encodePacked(sha256(_b)));
    }

    /// @notice Implements Bitcoin's double SHA256 hash with endianness correction
    /// @dev This is how Bitcoin calls double SHA256 and we reverse it to correct endian
    /// @dev Converts from little endian (used by Bitcoin) to big endian (used by humans)
    /// @dev See: https://learnmeabitcoin.com/technical/general/byte-order/
    /// @param _toHash The data to hash
    /// @return The double SHA256 hash in big endian format
    function hash256(bytes memory _toHash) internal pure returns (bytes32) {
        bytes32 littleEndianHash = sha256(abi.encodePacked(sha256(_toHash)));
        return reverseBytes32(littleEndianHash);
    }

    /// @notice Reverses the byte order of a bytes32 value
    /// @dev Used to convert between little endian (used by Bitcoin) and big endian (used by humans)
    /// @dev See: https://ethereum.stackexchange.com/questions/83626/how-to-reverse-byte-order-in-uint256-or-bytes32#answer-83627
    /// @param _input The bytes32 value to reverse
    /// @return v The reversed bytes32 value
    function reverseBytes32(bytes32 _input) internal pure returns (bytes32 v) {
        v = _input;

        // swap bytes
        v = ((v & 0xFF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00) >> 8)
            | ((v & 0x00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF) << 8);

        // swap 2-byte long pairs
        v = ((v & 0xFFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000) >> 16)
            | ((v & 0x0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF) << 16);

        // swap 4-byte long pairs
        v = ((v & 0xFFFFFFFF00000000FFFFFFFF00000000FFFFFFFF00000000FFFFFFFF00000000) >> 32)
            | ((v & 0x00000000FFFFFFFF00000000FFFFFFFF00000000FFFFFFFF00000000FFFFFFFF) << 32);

        // swap 8-byte long pairs
        v = ((v & 0xFFFFFFFFFFFFFFFF0000000000000000FFFFFFFFFFFFFFFF0000000000000000) >> 64)
            | ((v & 0x0000000000000000FFFFFFFFFFFFFFFF0000000000000000FFFFFFFFFFFFFFFF) << 64);

        // swap 16-byte long pairs
        v = (v >> 128) | (v << 128);
    }

    /// @notice Changes the endianness of a uint64
    /// @dev Converts between little endian (used by Bitcoin) and big endian (used by humans)
    /// @param _b The unsigned integer to reverse
    /// @return v The reversed value
    /// @dev See: https://github.com/bob-collective/bitcoin-spv/blob/master/src/BTCUtils.sol#L127
    function reverseUint64(uint64 _b) internal pure returns (uint64 v) {
        v = _b;

        // swap bytes
        v = ((v >> 8) & 0x00FF00FF00FF00FF) | ((v & 0x00FF00FF00FF00FF) << 8);
        // swap 2-byte long pairs
        v = ((v >> 16) & 0x0000FFFF0000FFFF) | ((v & 0x0000FFFF0000FFFF) << 16);
        // swap 4-byte long pairs
        v = (v >> 32) | (v << 32);
    }

    /// @notice Changes the endianness of a uint32
    /// @dev Converts between little endian (used by Bitcoin) and big endian (used by humans)
    /// @param _b The unsigned integer to reverse
    /// @return v The reversed value
    /// @dev See: https://github.com/bob-collective/bitcoin-spv/blob/master/src/BTCUtils.sol#L143
    function reverseUint32(uint32 _b) internal pure returns (uint32 v) {
        v = _b;

        // swap bytes
        v = ((v >> 8) & 0x00FF00FF) | ((v & 0x00FF00FF) << 8);
        // swap 2-byte long pairs
        v = (v >> 16) | (v << 16);
    }

    /// @notice Changes the endianness of a uint24
    /// @dev Converts between little endian (used by Bitcoin) and big endian (used by humans)
    /// @param _b The unsigned integer to reverse
    /// @return v The reversed value
    function reverseUint24(uint24 _b) internal pure returns (uint24 v) {
        v = (_b << 16) | (_b & 0x00FF00) | (_b >> 16);
    }

    /// @notice Changes the endianness of a uint16
    /// @dev Converts between little endian (used by Bitcoin) and big endian (used by humans)
    /// @param _b The unsigned integer to reverse
    /// @return v The reversed value
    /// @dev See: https://github.com/bob-collective/bitcoin-spv/blob/master/src/BTCUtils.sol#L163
    function reverseUint16(uint16 _b) internal pure returns (uint16 v) {
        v = (_b << 8) | (_b >> 8);
    }

    /// @notice Calculate fee and speed-up amounts for Bitcoin transactions
    /// @dev TODO: calculate fee and speed up properly from the amount
    /// @dev Currently returns fixed values from Constants
    /// @return The fee amount in satoshis
    /// @return The speed-up amount in satoshis
    function calculateFeeAndSpeedUp() internal pure returns (uint64, uint64) {
        return (Constants.P2TR_FEE, Constants.SPEED_UP_AMOUNT);
    }

    /// @notice Convert wei amount to satoshis
    /// @dev Divides by 10^10 to convert from wei used in RSK to satoshis used in Bitcoin
    /// @param _amount The amount in wei
    /// @return The amount in satoshis
    function weiToSatoshi(uint256 _amount) internal pure returns (uint256) {
        return _amount / 10 ** 10;
    }

    /// @notice Convert satoshis to wei amount
    /// @dev Multiplies by 10^10 to convert from satoshis used in Bitcoin to wei used in RSK
    /// @param _amount The amount in satoshis
    /// @return The amount in wei
    function satoshiToWei(uint256 _amount) internal pure returns (uint256) {
        return _amount * 10 ** 10;
    }

    /// @notice Converts a bytes32 public key to a bytes format
    /// @dev The public key is expected to be in the compressed format (x-coordinate only)
    /// @dev The first byte is set to 0x02 to indicate a compressed public key
    /// @param _pubKey The public key in bytes32 format
    /// @return The public key in bytes format
    function pubKeyXonlyToCompact(bytes32 _pubKey) internal pure returns (bytes memory) {
        return abi.encodePacked(uint8(0x02), _pubKey);
    }
}
