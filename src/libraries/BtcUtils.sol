// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title Btc Utils
 * @notice Usefull functions for Bitcoin parsin/encoding/decoding
 * @author Fairgate
 */
library BtcUtils {
    /// @dev This is how Bitcoin calls double sha256 and we reverse it to correct endian
    function hash256(bytes memory _toHash) internal pure returns (bytes32) {
        bytes32 littleEndianHash = sha256(abi.encode(sha256(_toHash)));
        // reverse bits
        // converts from little endian (used by Bitcoin) to big endian (used by humans)
        // https://learnmeabitcoin.com/technical/general/byte-order/#:~:text=In%20both%20transaction%20and%20block,we%20humans%20write%20numbers%20down.
        return reverseBytes32(littleEndianHash);
    }

    function reverseBytes32(bytes32 _input) internal pure returns (bytes32 v) {
        // Function to reverse bytes
        // https://ethereum.stackexchange.com/questions/83626/how-to-reverse-byte-order-in-uint256-or-bytes32#answer-83627
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

    /// @notice          Changes the endianness of a uint64
    /// @param _b        The unsigned integer to reverse
    /// @return v        The reversed value
    /// https://github.com/bob-collective/bitcoin-spv/blob/8f375250198ff5d2fb95ee2ccf72d835cd7ca4c2/src/BTCUtils.sol
    function reverseUint64(uint64 _b) internal pure returns (uint64 v) {
        v = _b;

        // swap bytes
        v = ((v >> 8) & 0x00FF00FF00FF00FF) | ((v & 0x00FF00FF00FF00FF) << 8);
        // swap 2-byte long pairs
        v = ((v >> 16) & 0x0000FFFF0000FFFF) | ((v & 0x0000FFFF0000FFFF) << 16);
        // swap 4-byte long pairs
        v = (v >> 32) | (v << 32);
    }

    /// @notice          Changes the endianness of a uint32
    /// @param _b        The unsigned integer to reverse
    /// @return v        The reversed value
    /// https://github.com/bob-collective/bitcoin-spv/blob/8f375250198ff5d2fb95ee2ccf72d835cd7ca4c2/src/BTCUtils.sol
    function reverseUint32(uint32 _b) internal pure returns (uint32 v) {
        v = _b;

        // swap bytes
        v = ((v >> 8) & 0x00FF00FF) | ((v & 0x00FF00FF) << 8);
        // swap 2-byte long pairs
        v = (v >> 16) | (v << 16);
    }

    /// @notice          Changes the endianness of a uint16
    /// @param _b        The unsigned integer to reverse
    /// @return v        The reversed value
    /// https://github.com/bob-collective/bitcoin-spv/blob/8f375250198ff5d2fb95ee2ccf72d835cd7ca4c2/src/BTCUtils.sol
    function reverseUint16(uint16 _b) internal pure returns (uint16 v) {
        v = (_b << 8) | (_b >> 8);
    }
}
