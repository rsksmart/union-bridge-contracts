// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title Btc Utils
 * @notice Usefull functions for Bitcoin parsin/encoding/decoding
 * @author Fairgate
 */
library BtcHelper {
    /// @dev returns hex bytes with _size in btc compact _size
    /// The first byte indicates which bytes encode the integer:
    /// <= FC – This byte (0 - 252)
    /// FD – The next two bytes (253 - 65535)
    /// FE – The next four bytes (65536 - 4294967295)
    /// FF – The next eight bytes (4294967296 - 18446744073709551615)
    // Note: Bytes encoding the integer are in little endian.
    // https://learnmeabitcoin.com/technical/general/compact-_size/
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

    /// @notice Implements Bitcoin's tagged hash algorithm used in Taproot
    /// @dev Computes sha256(tagHash || tagHash || data) where tagHash = sha256(tag)
    /// @param _tag The tag string to use (e.g. "TapTweak", "TapLeaf", etc)
    /// @param _data The data to hash
    /// @return taggedHash
    /// @custom:ref https://github.com/bitcoin/bips/blob/master/bip-0340.mediawiki#tagged-hashes
    function taggedHash(bytes memory _tag, bytes memory _data) internal pure returns (bytes32) {
        bytes32 tagHash = sha256(_tag);
        return sha256(abi.encodePacked(tagHash, tagHash, _data));
    }

    /// @notice          Implements bitcoin's hash160 (rmd160(sha2()))
    /// @dev             abi.encodePacked changes the return to bytes instead of bytes32
    /// @param _b        The pre-image
    /// @return          The digest
    /// https://github.com/bob-collective/bitcoin-spv/blob/master/src/BTCUtils.sol#L192C5-L198C6
    function hash160(bytes memory _b) internal pure returns (bytes memory) {
        return abi.encodePacked(ripemd160(abi.encodePacked(sha256(_b))));
    }

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
    /// https://github.com/bob-collective/bitcoin-spv/blob/master/src/BTCUtils.sol#L127
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
    /// https://github.com/bob-collective/bitcoin-spv/blob/master/src/BTCUtils.sol#L143
    function reverseUint32(uint32 _b) internal pure returns (uint32 v) {
        v = _b;

        // swap bytes
        v = ((v >> 8) & 0x00FF00FF) | ((v & 0x00FF00FF) << 8);
        // swap 2-byte long pairs
        v = (v >> 16) | (v << 16);
    }

    /// @notice          Changes the endianness of a uint24
    /// @param _b        The unsigned integer to reverse
    /// @return v        The reversed value
    function reverseUint24(uint24 _b) internal pure returns (uint24 v) {
        v = (_b << 16) | (_b & 0x00FF00) | (_b >> 16);
    }

    /// @notice          Changes the endianness of a uint16
    /// @param _b        The unsigned integer to reverse
    /// @return v        The reversed value
    /// https://github.com/bob-collective/bitcoin-spv/blob/master/src/BTCUtils.sol#L163
    function reverseUint16(uint16 _b) internal pure returns (uint16 v) {
        v = (_b << 8) | (_b >> 8);
    }

    // TODO calculate fee and dust properly from the amount
    function calculateFeeAndDust(uint64) internal pure returns (uint64, uint64) {
        uint64 fee = 1;
        uint64 dust = 350;
        return (fee, dust);
    }

    function weiToSatoshi(uint256 _amount) internal pure returns (uint256) {
        return _amount / 10 ** 10;
    }

    function satoshiToWei(uint256 _amount) internal pure returns (uint256) {
        return _amount * 10 ** 10;
    }
}
