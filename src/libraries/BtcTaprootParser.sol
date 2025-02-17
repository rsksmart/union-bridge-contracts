// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {OpCodes} from "./OpCodes.sol";
import {Secp256k1} from "./Secp256k1.sol";
import {BtcHelper} from "./BtcHelper.sol";

/**
 * @title Bitcoin Address Parser
 * @notice Allows to encode / decode Bitcoin Addresses
 * @author Fairgate
 */
library BtcTaprootParser {
    bytes constant TAP_TWEAK = bytes("TapTweak");
    bytes1 constant LEAF_VERSION = 0xc0; // number 192 aka tapscript
    bytes constant TAP_LEAF = bytes("TapLeaf");
    bytes constant TAP_BRANCH = bytes("TapBranch");

    /// @notice Generates a Taproot PubScript.
    /// @param _publicKey The public key used to create the locking script (x-only, 32 bytes)
    /// @param _merkleRoot The root hash of the Taproot scripts merkle tree. If empty it wll
    /// @return scriptPubKey  bytes (32 bytes output y + 2 byte script pubkey prefix)
    /// @dev If you do not use a script tree, your merkle will be empty (zero bytes).
    /// https://learnmeabitcoin.com/technical/upgrades/taproot/
    function getP2TRScriptPubKey(bytes32 _publicKey, bytes32 _merkleRoot, bytes memory customTweakData)
        internal
        pure
        returns (bytes memory)
    {
        bytes32 tweak;
        // If you are not using a script tree, the data will just be the public key.
        if (_merkleRoot == bytes32(0)) {
            // Get Key path tweak
            tweak = getTweak(abi.encodePacked(_publicKey, customTweakData));
        } else {
            // Get Script path tweak
            tweak = getTweak(abi.encodePacked(_publicKey, _merkleRoot, customTweakData));
        }
        bytes32 tweakedPublicKey = getTweakedPublicKey(_publicKey, tweak);
        return getP2TRScriptPubKey(tweakedPublicKey);
    }

    /// @dev https://learnmeabitcoin.com/technical/upgrades/taproot/#tweak
    function getTweak(bytes memory data) internal pure returns (bytes32) {
        return BtcHelper.taggedHash(TAP_TWEAK, data);
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
    function getP2TRScriptPubKey(bytes32 tweakedPublicKey) private pure returns (bytes memory) {
        // OP_1 (0x51) OP_PUSHBYTES_32 (0x20) <32-byte tweaked public key>
        return abi.encodePacked(OpCodes.OP_1, OpCodes.OP_PUSHBYTES_32, tweakedPublicKey);
    }

    /// @dev https://learnmeabitcoin.com/technical/upgrades/taproot/#script-tree-merkle-root-leaf-hash
    function getLeaf(bytes memory _script) internal pure returns (bytes32) {
        bytes memory data = abi.encodePacked(LEAF_VERSION, BtcHelper.toCompactSize(_script.length), _script);
        return BtcHelper.taggedHash(TAP_LEAF, data);
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
        return BtcHelper.taggedHash(TAP_BRANCH, data);
    }
}
