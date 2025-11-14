// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {OpCodes} from "./OpCodes.sol";
import {Secp256k1} from "./Secp256k1.sol";
import {BtcHelper} from "./BtcHelper.sol";

/// @title Bitcoin Taproot Library
/// @notice Functions needed to create Bitcoin Taproot scripts and addresses
/// @dev Implements Taproot functionality as specified in BIP-340, BIP-341, and BIP-342
/// @dev Used for creating P2TR (Pay-to-Taproot) addresses and scripts in the union bridge
/// @author Fairgate
library BtcTaproot {
    // Taproot Constants
    /// @dev Tag for TapTweak hash calculation
    /// @dev Used in the tweaked public key derivation process
    bytes constant TAP_TWEAK = bytes("TapTweak");

    /// @dev Leaf version for Taproot scripts (0xc0 = 192)
    /// @dev Indicates this is a tapscript leaf in the script tree
    bytes1 constant LEAF_VERSION = 0xc0; // number 192 aka tapscript

    /// @dev Tag for TapLeaf hash calculation
    /// @dev Used when hashing script leaves in the script tree
    bytes constant TAP_LEAF = bytes("TapLeaf");

    /// @dev Tag for TapBranch hash calculation
    /// @dev Used when hashing branches in the script tree
    bytes constant TAP_BRANCH = bytes("TapBranch");

    /// @dev Tag for TapSighash calculation
    /// @dev Used when creating the signature hash for Taproot transactions
    bytes constant TAP_SIGHASH = bytes("TapSighash");

    /// @notice Implements Bitcoin's tagged hash algorithm used in Taproot
    /// @dev Computes sha256(tagHash || tagHash || data) where tagHash = sha256(tag)
    /// @dev This prevents hash collisions between different Taproot operations
    /// @param _tag The tag string to use (e.g. "TapTweak", "TapLeaf", etc)
    /// @param _data The data to hash
    /// @return taggedHash The tagged hash result
    /// @custom:ref https://github.com/bitcoin/bips/blob/master/bip-0340.mediawiki#tagged-hashes
    function taggedHash(bytes memory _tag, bytes memory _data) internal pure returns (bytes32) {
        bytes32 tagHash = sha256(_tag);
        return sha256(abi.encodePacked(tagHash, tagHash, _data));
    }

    /// @notice Creates the signature hash for Taproot transactions
    /// @dev Uses the TapSighash tag to create a unique hash for signing
    /// @dev See: https://learnmeabitcoin.com/technical/upgrades/taproot/#tweak
    /// @param data The transaction data to hash
    /// @return The signature hash for the transaction
    function getSighash(bytes memory data) internal pure returns (bytes32) {
        return taggedHash(TAP_SIGHASH, data);
    }

    /// @notice Creates the tweak value for Taproot public key derivation
    /// @dev Uses the TapTweak tag to create a tweak for the internal key
    /// @dev See: https://learnmeabitcoin.com/technical/upgrades/taproot/#tweak
    /// @param data The data to create the tweak from
    /// @return The tweak value
    function getTweak(bytes memory data) internal pure returns (bytes32) {
        return taggedHash(TAP_TWEAK, data);
    }

    /// @notice Derives the tweaked public key for Taproot
    /// @dev Combines the internal public key with the tweak using elliptic curve operations
    /// @dev See: https://learnmeabitcoin.com/technical/upgrades/taproot/#tweaked-public-key
    /// @param _publicKey The internal public key (x-coordinate only)
    /// @param _tweak The tweak value to apply
    /// @return The tweaked public key (x-coordinate only)
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

    /// @notice Creates a P2TR (Pay-to-Taproot) scriptPubKey
    /// @dev Creates the script that locks funds to a Taproot address
    /// @dev See: https://learnmeabitcoin.com/technical/upgrades/taproot/#scriptpubkey
    /// @param tweakedPublicKey The tweaked public key (x-coordinate only)
    /// @return The P2TR scriptPubKey bytes
    function getP2TRScriptPubKey(bytes32 tweakedPublicKey) internal pure returns (bytes memory) {
        // OP_1 (0x51) OP_PUSHBYTES_32 (0x20) <32-byte tweaked public key>
        return abi.encodePacked(OpCodes.OP_1, OpCodes.OP_PUSHBYTES_32, tweakedPublicKey);
    }

    /// @notice Creates a leaf hash for the Taproot script tree
    /// @dev Hashes a script with the TapLeaf tag to create a leaf in the script tree
    /// @dev See: https://learnmeabitcoin.com/technical/upgrades/taproot/#script-tree-merkle-root-leaf-hash
    /// @param _script The script to hash
    /// @return The leaf hash
    function getLeaf(bytes memory _script) internal pure returns (bytes32) {
        bytes memory data = abi.encodePacked(LEAF_VERSION, BtcHelper.toCompactSize(_script.length), _script);
        return taggedHash(TAP_LEAF, data);
    }

    /// @notice Creates a branch hash for the Taproot script tree
    /// @dev Combines two leaves or branches with the TapBranch tag
    /// @dev See: https://learnmeabitcoin.com/technical/upgrades/taproot/#script-tree-merkle-root-branch-hash
    /// @param _leafOrBranch The first leaf or branch hash
    /// @param _otherLeafOrBranch The second leaf or branch hash
    /// @return The branch hash
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
