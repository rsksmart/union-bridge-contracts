// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Obtained from https://github.com/GNSPS/solidity-bytes-utils/blob/master/contracts/BytesLib.sol
library BytesHelper {
    error indexOverflow(uint256 length, uint256 from, uint256 upTo);

    function compare(bytes memory a, bytes memory b) internal pure returns (bool) {
        return (a.length == b.length) && (keccak256(a) == keccak256(b));
    }

    function stringCompare(string memory a, string memory b) internal pure returns (bool) {
        return compare(bytes(a), bytes(b));
    }

    function getBytesToString(bytes memory _bytes, uint256 _from, uint256 _length)
        internal
        pure
        returns (string memory)
    {
        uint256 _upTo = _from + _length;
        if (_upTo < _from) {
            revert indexOverflow(_bytes.length, _from, _upTo);
        }
        if (_bytes.length < _upTo) {
            revert indexOverflow(_bytes.length, _from, _upTo);
        }
        return string(slice(_bytes, _from, _length));
    }

    function bytesToBytes32(bytes memory _bytes, uint256 _from) internal pure returns (bytes32) {
        uint256 upTo = _from + 32;
        if (_bytes.length < upTo) {
            revert indexOverflow(_bytes.length, _from, upTo);
        }
        bytes32 tempBytes32;
        assembly {
            tempBytes32 := mload(add(add(_bytes, 0x20), _from))
        }

        return tempBytes32;
    }

    function bytesToAddress(bytes memory _bytes, uint256 _from) internal pure returns (address) {
        // Address are 20 bytes long
        uint256 upTo = _from + 20;
        if (_bytes.length < upTo) {
            revert indexOverflow(_bytes.length, _from, upTo);
        }
        address tempAddress;
        assembly {
            tempAddress := mload(add(add(_bytes, 0x14), _from))
        }
        return tempAddress;
    }

    function bytesToUint64(bytes memory _bytes, uint256 _from) internal pure returns (uint64) {
        // uint64 are 8 bytes long
        uint256 upTo = _from + 8;
        if (_bytes.length < upTo) {
            revert indexOverflow(_bytes.length, _from, upTo);
        }
        uint64 tempUint;
        assembly {
            tempUint := mload(add(add(_bytes, 0x8), _from))
        }
        return tempUint;
    }

    function slice(bytes memory _bytes, uint256 _start, uint256 _length) internal pure returns (bytes memory) {
        if (_length + 31 < _length) {
            // slice_overflow
            revert indexOverflow(_bytes.length, _start, _length + 31);
        }
        if (_bytes.length < _start + _length) {
            revert indexOverflow(_bytes.length, _start, _start + _length);
        }

        bytes memory tempBytes;
        assembly {
            switch iszero(_length)
            case 0 {
                // Get a location of some free memory and store it in tempBytes as
                // Solidity does for memory variables.
                tempBytes := mload(0x40)

                // The first word of the slice result is potentially a partial
                // word read from the original array. To read it, we calculate
                // the length of that partial word and start copying that many
                // bytes into the array. The first word we copy will start with
                // data we don't care about, but the last `lengthmod` bytes will
                // land at the beginning of the contents of the new array. When
                // we're done copying, we overwrite the full first word with
                // the actual length of the slice.
                let lengthmod := and(_length, 31)

                // The multiplication in the next line is necessary
                // because when slicing multiples of 32 bytes (lengthmod == 0)
                // the following copy loop was copying the origin's length
                // and then ending prematurely not copying everything it should.
                let mc := add(add(tempBytes, lengthmod), mul(0x20, iszero(lengthmod)))
                let end := add(mc, _length)

                for {
                    // The multiplication in the next line has the same exact purpose
                    // as the one above.
                    let cc := add(add(add(_bytes, lengthmod), mul(0x20, iszero(lengthmod))), _start)
                } lt(mc, end) {
                    mc := add(mc, 0x20)
                    cc := add(cc, 0x20)
                } { mstore(mc, mload(cc)) }

                mstore(tempBytes, _length)

                //update free-memory pointer
                //allocating the array padded to 32 bytes like the compiler does now
                mstore(0x40, and(add(mc, 31), not(31)))
            }
            //if we want a zero-length slice let's just return a zero-length array
            default {
                tempBytes := mload(0x40)
                //zero out the 32 bytes slice we are about to return
                //we need to do it because Solidity does not garbage collect
                mstore(tempBytes, 0)

                mstore(0x40, add(tempBytes, 0x20))
            }
        }

        return tempBytes;
    }
}
