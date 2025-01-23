// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library BytesHelper {
    error indexOverflow(uint256 length, uint256 from, uint256 upTo);

    function compare(bytes calldata a, bytes calldata b) public pure returns (bool) {
        return (a.length == b.length) && (keccak256(a) == keccak256(b));
    }

    function stringCompare(string calldata a, string calldata b) public pure returns (bool) {
        return compare(bytes(a), bytes(b));
    }

    function bytesToString(bytes calldata _bytes, uint256 _from, uint256 _upTo) public pure returns (string calldata) {
        if (_upTo < _from) {
            revert indexOverflow(_bytes.length, _from, _upTo);
        }
        if (_bytes.length < _upTo) {
            revert indexOverflow(_bytes.length, _from, _upTo);
        }
        return string(_bytes[_from:_upTo]);
    }

    function bytesToAddress(bytes calldata _bytes, uint256 _from) public pure returns (address) {
        // Address are 20 bytes long
        uint256 upTo = _from + 20;
        if (_bytes.length < upTo) {
            revert indexOverflow(_bytes.length, _from, upTo);
        }
        return address(uint160(bytes20(_bytes[_from:])));
    }

    function bytesToUint64(bytes calldata _bytes, uint256 _from) public pure returns (uint64) {
        // uint64 are 8 bytes long
        uint256 upTo = _from + 8;
        if (_bytes.length < upTo) {
            revert indexOverflow(_bytes.length, _from, upTo);
        }
        return uint64(bytes8(_bytes[_from:]));
    }
}
