// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import {BtcNetwork} from "./Network.sol";

/// @title Bech32m
/// @notice Library for Bech32m encoding and decoding used in Bitcoin Taproot addresses
/// @dev Implements the Bech32m checksum algorithm as specified in BIP-0350
/// @dev Used for encoding Taproot addresses (P2TR) in the union bridge
library Bech32m {
    /// @notice Error thrown when an invalid Bitcoin network is provided
    /// @param network The invalid network value that was provided
    error InvalidNetwork(BtcNetwork network);

    /// @notice Error thrown when invalid padding is detected during bit conversion
    /// @dev Occurs when the padding flag is false but padding would be required
    error InvalidPadding();

    /// @notice Error thrown when a value exceeds the maximum allowed for the given bit size
    /// @param value The value that exceeded the maximum allowed range
    error InvalidBitsSize(uint256 value);

    /// @notice Error thrown when a tweaked public key has an invalid length
    /// @param length The actual length of the tweaked public key
    /// @param expected The expected length (32 bytes)
    error InvalidTweakedPublicKeyLength(uint256 length, uint256 expected);

    // Bech32m Constants
    /// @dev Character set for Bech32m encoding (32 characters)
    /// @dev Used to convert 5-bit values to human-readable characters
    bytes constant CHARSET = "qpzry9x8gf2tvdw0s3jn54khce6mua7l";

    /// @dev Bech32m constant for checksum calculation
    /// @dev XORed with the polynomial modulo result to create the checksum
    uint32 constant BECH32M_CONST = 0x2bc830a3;

    // Generator Constants for Polymod
    /// @dev Generator constant 0 for polynomial modulo calculation
    uint32 constant GENERATOR_0 = 0x3b6a57b2;

    /// @dev Generator constant 1 for polynomial modulo calculation
    uint32 constant GENERATOR_1 = 0x26508e6d;

    /// @dev Generator constant 2 for polynomial modulo calculation
    uint32 constant GENERATOR_2 = 0x1ea119fa;

    /// @dev Generator constant 3 for polynomial modulo calculation
    uint32 constant GENERATOR_3 = 0x3d4233dd;

    /// @dev Generator constant 4 for polynomial modulo calculation
    uint32 constant GENERATOR_4 = 0x2a1462b3;

    /// @notice Calculate the polynomial modulo for Bech32m checksum
    /// @dev Implements the polynomial modulo algorithm used in Bech32m
    /// @param values Array of 5-bit values to process
    /// @return The polynomial modulo result
    function bech32Polymod(uint8[] memory values) internal pure returns (uint32) {
        uint32 chk = 1;
        for (uint256 i = 0; i < values.length; i++) {
            uint32 top = chk >> 25;
            chk = (chk & 0x1ffffff) << 5 ^ values[i];
            for (uint256 j = 0; j < 5; j++) {
                if ((top >> j) & 1 == 1) {
                    if (j == 0) chk ^= GENERATOR_0;
                    else if (j == 1) chk ^= GENERATOR_1;
                    else if (j == 2) chk ^= GENERATOR_2;
                    else if (j == 3) chk ^= GENERATOR_3;
                    else if (j == 4) chk ^= GENERATOR_4;
                }
            }
        }
        return chk;
    }

    /// @notice Expand the human-readable part (HRP) for checksum calculation
    /// @dev Converts the HRP string into an array of 5-bit values
    /// @param hrp Human-readable part string (e.g., "bc", "tb", "bcrt")
    /// @return Array of 5-bit values representing the expanded HRP
    function bech32HrpExpand(string memory hrp) internal pure returns (uint8[] memory) {
        bytes memory hrpBytes = bytes(hrp);
        uint8[] memory expand = new uint8[](2 * hrpBytes.length + 1);

        for (uint256 i = 0; i < hrpBytes.length; i++) {
            expand[i] = uint8(bytes1(hrpBytes[i])) >> 5;
            expand[hrpBytes.length + 1 + i] = uint8(bytes1(hrpBytes[i])) & 31;
        }
        expand[hrpBytes.length] = 0;
        return expand;
    }

    /// @notice Convert data between different bit sizes
    /// @dev Converts data from fromBits to toBits, with optional padding
    /// @param data Input data to convert
    /// @param fromBits Source bit size
    /// @param toBits Target bit size
    /// @param pad Whether to pad the output if necessary
    /// @return Array of converted data in the target bit size
    function convertBits(bytes memory data, uint8 fromBits, uint8 toBits, bool pad)
        internal
        pure
        returns (uint8[] memory)
    {
        uint256 acc = 0;
        uint256 bits = 0;
        uint256 maxv = (1 << toBits) - 1;
        uint256 maxacc = (1 << (fromBits + toBits - 1)) - 1;

        uint8[] memory ret = new uint8[](data.length * fromBits / toBits + 1);
        uint256 outLen = 0;

        for (uint256 i = 0; i < data.length; i++) {
            uint256 value = uint8(data[i]);
            if (value >> fromBits != 0) {
                revert InvalidBitsSize(value);
            }
            acc = ((acc << fromBits) | value) & maxacc;
            bits += fromBits;
            while (bits >= toBits) {
                bits -= toBits;
                ret[outLen++] = uint8((acc >> bits) & maxv);
            }
        }

        if (pad) {
            if (bits > 0) {
                ret[outLen++] = uint8((acc << (toBits - bits)) & maxv);
            }
        } else if (bits >= fromBits || ((acc << (toBits - bits)) & maxv) != 0) {
            revert InvalidPadding();
        }

        // Resize array to actual length
        assembly {
            mstore(ret, outLen)
        }
        return ret;
    }

    /// @notice Create a Bech32m checksum for the given HRP and data
    /// @dev Calculates the 6-character checksum using the Bech32m algorithm
    /// @param hrp Human-readable part string
    /// @param data Array of 5-bit data values
    /// @return Array of 6 checksum values
    function bech32CreateChecksum(string memory hrp, uint8[] memory data) internal pure returns (uint8[] memory) {
        uint8[] memory hrpExpanded = bech32HrpExpand(hrp);
        uint8[] memory values = new uint8[](hrpExpanded.length + data.length + 6);

        for (uint256 i = 0; i < hrpExpanded.length; i++) {
            values[i] = hrpExpanded[i];
        }
        for (uint256 i = 0; i < data.length; i++) {
            values[hrpExpanded.length + i] = data[i];
        }

        uint32 polymod = bech32Polymod(values) ^ BECH32M_CONST;
        uint8[] memory checksum = new uint8[](6);

        for (uint256 i = 0; i < 6; i++) {
            checksum[i] = uint8((polymod >> (5 * (5 - i))) & 31);
        }
        return checksum;
    }

    /// @notice Encode a Taproot public key as a Bech32m address
    /// @dev Creates a P2TR (Pay-to-Taproot) address from a tweaked public key
    /// @param tweakedPubKey The 32-byte tweaked public key
    /// @param network The Bitcoin network (mainnet, testnet, or regtest)
    /// @return The encoded Bech32m Taproot address
    function encodeTaprootAddress(bytes memory tweakedPubKey, BtcNetwork network)
        internal
        pure
        returns (string memory)
    {
        // Validate tweaked public key length is 32 bytes
        if (tweakedPubKey.length != 32) {
            revert InvalidTweakedPublicKeyLength(tweakedPubKey.length, 32);
        }
        // Convert to 5-bit words
        uint8[] memory words = convertBits(tweakedPubKey, 8, 5, true);

        // Prepare witness version and program
        uint8[] memory program = new uint8[](words.length + 1);
        program[0] = 1; // Witness version 1 for Taproot
        for (uint256 i = 0; i < words.length; i++) {
            program[i + 1] = words[i];
        }

        // Determine HRP based on network
        string memory hrp;
        if (network == BtcNetwork.MAINNET) {
            hrp = "bc";
        } else if (network == BtcNetwork.TESTNET) {
            hrp = "tb";
        } else if (network == BtcNetwork.REGTEST) {
            hrp = "bcrt";
        } else {
            revert InvalidNetwork(network);
        }

        // Get checksum
        uint8[] memory checksum = bech32CreateChecksum(hrp, program);

        // Combine everything
        bytes memory result = new bytes(program.length + checksum.length);
        for (uint256 i = 0; i < program.length; i++) {
            result[i] = CHARSET[program[i]];
        }
        for (uint256 i = 0; i < checksum.length; i++) {
            result[program.length + i] = CHARSET[checksum[i]];
        }

        // Concatenate final result with appropriate prefix
        return string(abi.encodePacked(hrp, "1", result));
    }
}
