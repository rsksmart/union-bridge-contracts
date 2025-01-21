// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title Btc Helper
 * @notice Usefull functions for Bitcoin parsin/encoding/decoding
 * @author Fairgate
 */
library BtcHelper {
    /// @dev This is how Bitcoin calls double sha256
    function hash256(bytes memory _toHash) internal pure returns (bytes32) {
        bytes32 bigEndianHash = sha256(abi.encode(sha256(_toHash)));
        // reverse bits
        // converts from little endian (used by Bitcoin) to big endian (used by humans)
        // https://learnmeabitcoin.com/technical/general/byte-order/#:~:text=In%20both%20transaction%20and%20block,we%20humans%20write%20numbers%20down.
        return reverse(bigEndianHash);
    }

    function reverse(bytes32 input) internal pure returns (bytes32 v) {
        // Function to reverse bytes
        // https://ethereum.stackexchange.com/questions/83626/how-to-reverse-byte-order-in-uint256-or-bytes32#answer-83627
        v = input;

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
}
