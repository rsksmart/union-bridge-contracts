// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {OpCodes} from "./OpCodes.sol";
import {Secp256k1} from "./Secp256k1.sol";

/**
 * @title Bitcoin Address Parser
 * @notice Allows to encode / decode Bitcoin Addresses
 * @author Fairgate
 */
library BtcAddressParser {
    bytes constant TAP_TWEAK = bytes("TapTweak");

    /// @notice Generates a Taproot PubScript where you provide a signature for the public key
    /// used to create the locking script. This works in a similar way to a simple P2WPKH.
    /// @param _publicKey The public key used to create the locking script (x-only, 32 bytes)
    /// @return scriptPubKey  bytes (32 bytes output y + 2 byte script pubkey prefix)
    /// @dev https://learnmeabitcoin.com/technical/upgrades/taproot/
    function getP2TRKeyPathScriptPubKey(bytes32 _publicKey) internal pure returns (bytes memory) {
        // Get Key path Script tweak
        bytes32 tweak = getTweak(abi.encodePacked(_publicKey));
        bytes32 tweakedPublicKey = getTweakedPublicKey(_publicKey, tweak);
        return getP2TRScriptPubKey(tweakedPublicKey);
    }

    /// @notice Generates a Taproot PubScript.
    /// @param _publicKey The public key used to create the locking script (x-only, 32 bytes)
    /// @param _merkleRoot The root hash of the Taproot scripts merkle tree. If empty it wll
    /// @return scriptPubKey  bytes (32 bytes output y + 2 byte script pubkey prefix)
    /// @dev https://learnmeabitcoin.com/technical/upgrades/taproot/
    function getP2TRScriptPathScriptPubKey(bytes32 _publicKey, bytes32 _merkleRoot)
        internal
        pure
        returns (bytes memory)
    {
        // Get Script path Script tweak
        bytes32 tweak = getTweak(abi.encodePacked(_publicKey, _merkleRoot));
        bytes32 tweakedPublicKey = getTweakedPublicKey(_publicKey, tweak);
        return getP2TRScriptPubKey(tweakedPublicKey);
    }

    /// @dev https://learnmeabitcoin.com/technical/upgrades/taproot/#tweak
    function getTweak(bytes memory data) private pure returns (bytes32) {
        return taggedHash(TAP_TWEAK, data);
    }

    /// @dev https://learnmeabitcoin.com/technical/upgrades/taproot/#tweaked-public-key
    function getTweakedPublicKey(bytes32 _publicKey, bytes32 _tweak) private pure returns (bytes32) {
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

    function taggedHash(bytes memory _tag, bytes memory _data) private pure returns (bytes32) {
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
}
