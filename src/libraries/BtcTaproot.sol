// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {OpCodes} from "./OpCodes.sol";
import {Secp256k1} from "./Secp256k1.sol";
import {BtcHelper} from "./BtcHelper.sol";

/**
 * @title Bitcoin Taproot Library
 * @notice functions needed to create Bitcoin Taproot scripts
 * @author Fairgate
 */
library BtcTaproot {
    bytes constant TAP_TWEAK = bytes("TapTweak");
    bytes1 constant LEAF_VERSION = 0xc0; // number 192 aka tapscript
    bytes constant TAP_LEAF = bytes("TapLeaf");
    bytes constant TAP_BRANCH = bytes("TapBranch");
    bytes constant TAP_SIGHASH = bytes("TapSighash");

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

    /// @dev https://learnmeabitcoin.com/technical/upgrades/taproot/#tweak
    function getTweak(bytes memory data) internal pure returns (bytes32) {
        return taggedHash(TAP_TWEAK, data);
    }

    /// @dev https://learnmeabitcoin.com/technical/upgrades/taproot/#tweaked-public-key
    function getTweakedPublicKey(bytes32 _publicKey, bytes32 _tweak) internal pure returns (bytes32) {
        // 1. Use tweak as internal key (x-only pubkey) to obtain y
        // The tweaked the public key (with TapTweak) is converted to integer (so it's like a private key)
        uint256 times = uint256(_tweak);
        uint256 publicKeyX = uint256(_publicKey);
        // 2. Get public key even y
        uint8 even = 0x02;
        uint256 publicKeyY = Secp256k1.deriveY(even, publicKeyX);
        // 3. Get X, Y point from  tweaked key
        (uint256 internalX, uint256 internalY) = Secp256k1.ecMul(times, Secp256k1.GX, Secp256k1.GY);
        // 4. Add tweaked key point to public key point
        (uint256 ouptputKeyX,) = Secp256k1.ecAdd(publicKeyX, publicKeyY, internalX, internalY);

        return bytes32(ouptputKeyX);
    }

    /// @dev https://learnmeabitcoin.com/technical/upgrades/taproot/#scriptpubkey
    function getP2TRScriptPubKey(bytes32 tweakedPublicKey) internal pure returns (bytes memory) {
        // OP_1 (0x51) OP_PUSHBYTES_32 (0x20) <32-byte tweaked public key>
        return abi.encodePacked(OpCodes.OP_1, OpCodes.OP_PUSHBYTES_32, tweakedPublicKey);
    }

    /// @dev https://learnmeabitcoin.com/technical/upgrades/taproot/#script-tree-merkle-root-leaf-hash
    function getLeaf(bytes memory _script) internal pure returns (bytes32) {
        bytes memory data = abi.encodePacked(LEAF_VERSION, BtcHelper.toCompactSize(_script.length), _script);
        return taggedHash(TAP_LEAF, data);
    }

    /// @dev https://learnmeabitcoin.com/technical/upgrades/taproot/#script-tree-merkle-root-branch-hash
    function getBranch(bytes32 _leafOrBranch, bytes32 _otherLeafOrBranch) internal pure returns (bytes32) {
        bytes32 lowerHash = _leafOrBranch;
        bytes32 higherHash = _otherLeafOrBranch;
        if (_leafOrBranch > _otherLeafOrBranch) {
            lowerHash = _otherLeafOrBranch;
            higherHash = _leafOrBranch;
        }
        bytes memory data = abi.encodePacked(lowerHash, higherHash);
        return taggedHash(TAP_BRANCH, data);
    }
}
