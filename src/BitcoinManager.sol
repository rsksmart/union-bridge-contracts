// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.19;

import "forge-std/console.sol";
import "./libraries/Secp256k1.sol";
import "./interfaces/IBitcoinManager.sol";

/// @title BitcoinManager
/// @notice Manages Bitcoin Addresses and Scripts
contract BitcoinManager is IBitcoinManager {
    function getTemporaryPegInAddress(
        bytes calldata rootstockDepositAddress,
        // bytes calldata bitcoinReimbursementAddress,
        uint64 value,
        bytes32 committeeKey // Get the current packet's committee key
    ) external view returns (bytes memory bitcoinDepositAddress) {
        console.log("committeeKey");
        console.logBytes32(committeeKey);

        // Create custom tweak from deposit address and value
        bytes32 customTweak = sha256(abi.encodePacked(rootstockDepositAddress, value));
        console.log("customTweak");
        console.logBytes32(customTweak);

        // Empty script root (no script path)
        // TODO make actual script root with other spending paths
        bytes32 emptyScriptRoot = bytes32(0);

        // Generate and return the taproot address
        return generateTaprootAddress(committeeKey, emptyScriptRoot, customTweak);
    }

    // TODO move bech32 functions to a separate library

    /// @notice Generates a Taproot address with both key spend and script spend paths
    /// @param internalKey The committee's public key (x-only, 32 bytes)
    /// @param scriptRoot The merkle root of the script spend path
    // /// @param customTweak Additional tweak data for address customization
    /// @return taprootAddress bytes (32 bytes output key + 1 byte version)
    function generateTaprootAddress(bytes32 internalKey, bytes32 scriptRoot, bytes32)
        public
        view
        returns (bytes memory)
    {
        // if script root is empty, do not include it in the tweak
        // TODO remove once we implement script path spend
        bytes32 tweakValue;
        if (scriptRoot == bytes32(0)) {
            tweakValue = taggedHash("TapTweak", abi.encodePacked(internalKey));
            // tweakValue = taggedHash("TapTweak", abi.encodePacked(internalKey, customTweak));
        } else {
            tweakValue = taggedHash("TapTweak", abi.encodePacked(internalKey, scriptRoot));
            // tweakValue = taggedHash("TapTweak", abi.encodePacked(internalKey, scriptRoot, customTweak));
        }

        console.log("tweakValue");
        console.logBytes32(tweakValue);

        // 2. Convert to Taproot ScriptPubKey
        bytes memory scriptPubKey = getScriptPubKey(tweakValue, internalKey);
        console.log("scriptPubKey");
        console.logBytes(scriptPubKey);

        // 3. Create tagged hash for taproot tweak
        bytes32 tweakedKey = generateAddressWithTweak(internalKey, tweakValue);
        console.log("tweakedKey");
        console.logBytes32(tweakedKey);

        // 4. Add Taproot version byte (0x01) to tweaked key
        return abi.encodePacked(hex"01", tweakedKey);
    }

    function taggedHash(string memory tag, bytes memory message) public view returns (bytes32) {
        console.log("message");
        console.logBytes(message);

        bytes32 tagHash = sha256(bytes(tag));
        bytes memory preimage = abi.encodePacked(tagHash, tagHash, message);

        return sha256(preimage);
    }

    /// @notice Generates a Taproot address with single key spend path
    /// @param tweakedKey The tweaked the public key (TapTweak) converted to integer (so it's like a private key)
    /// @param committeePubKey The committee's public key (x-only, 32 bytes)
    /// @return scriptPubKey  bytes (32 bytes output y + 2 byte script pubkey prefix)
    function getScriptPubKey(bytes32 tweakedKey, bytes32 committeePubKey) public pure returns (bytes memory) {
        // 1. Use tweaked key as internal key (x-only pubkey) to obtain y
        uint256 times = uint256(tweakedKey);
        uint256 committeePubKeyX = uint256(committeePubKey);
        // 2. Get committee even y
        uint8 even = 0x02;
        uint256 committeePubKeyY = Secp256k1.deriveY(even, committeePubKeyX);
        // 3. Get X, Y point from  tweaked key
        (uint256 internalX, uint256 internalY) = Secp256k1.ecMul(times, Secp256k1.GX, Secp256k1.GY);
        // 4. Add tweaked key point to committee point
        (uint256 ouptputKeyX,) = Secp256k1.ecAdd(committeePubKeyX, committeePubKeyY, internalX, internalY);

        // 5. Add Taproot script pub key prefix bytes (0x5120)
        return abi.encodePacked(hex"5120", ouptputKeyX);
    }

    /// @notice Generates a Taproot address with single key spend path
    /// @param committeeKey The committee's public key (x-only, 32 bytes)
    /// @return taprootAddress bytes (32 bytes output key + 1 byte version)
    function deriveKeySpendAddress(bytes32 committeeKey) public pure returns (bytes memory) {
        // 1. Use committee key as internal key (x-only pubkey)
        bytes32 outputKey = committeeKey;

        // 2. Add Taproot version byte (0x01)
        return abi.encodePacked(hex"01", outputKey);
    }

    // Generate addresses using different tweaks
    function generateAddressWithTweak(bytes32 internalPubKey, bytes32 customTweak) internal pure returns (bytes32) {
        // Create a unique address by XORing with a custom tweak
        bytes32 tagHash = sha256(abi.encodePacked("TapTweak"));
        return sha256(abi.encodePacked(tagHash, tagHash, internalPubKey, customTweak));
    }
}
