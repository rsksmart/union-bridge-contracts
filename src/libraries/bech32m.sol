// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Network} from "../network.sol";

// contract Bech32m {
library Bech32m {
    // Constants
    bytes constant CHARSET = "qpzry9x8gf2tvdw0s3jn54khce6mua7l";
    uint32 constant BECH32M_CONST = 0x2bc830a3;

    // Generator constants for polymod
    uint32 constant GENERATOR_0 = 0x3b6a57b2;
    uint32 constant GENERATOR_1 = 0x26508e6d;
    uint32 constant GENERATOR_2 = 0x1ea119fa;
    uint32 constant GENERATOR_3 = 0x3d4233dd;
    uint32 constant GENERATOR_4 = 0x2a1462b3;

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
                revert("Invalid value");
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
            revert("Invalid padding");
        }

        // Resize array to actual length
        assembly {
            mstore(ret, outLen)
        }
        return ret;
    }

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

    function encodeTaprootAddress(bytes memory pubkey, Network network) internal pure returns (string memory) {
        // Convert to 5-bit words
        uint8[] memory words = convertBits(pubkey, 8, 5, true);

        // Prepare witness version and program
        uint8[] memory program = new uint8[](words.length + 1);
        program[0] = 1; // Witness version 1 for Taproot
        for (uint256 i = 0; i < words.length; i++) {
            program[i + 1] = words[i];
        }

        // Determine HRP based on network
        string memory hrp;
        if (network == Network.MAINNET) {
            hrp = "bc";
        } else if (network == Network.TESTNET) {
            hrp = "tb";
        } else if (network == Network.REGTEST) {
            hrp = "bcrt";
        } else {
            revert("Invalid network");
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
