// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {OpCodes} from "./OpCodes.sol";
import {BtcHelper} from "./BtcHelper.sol";

/**
 * @title Bitcoin Script Parser
 * @notice Allows to encode / decode Bitcoin Scripts
 * @author Fairgate
 */
library BtcScriptParser {
    bytes1 constant LEAF_VERSION = 0xc0; // number 192 aka tapscript
    bytes constant TAP_LEAF = bytes("TapLeaf");
    bytes constant TAP_BRANCH = bytes("TapBranch");

    function getP2WPKHScript(bytes32 _publicKey) internal pure returns (bytes memory) {
        // Pay To Witness Public Key Hash
        return abi.encodePacked(OpCodes.OP_0, OpCodes.OP_PUSHBYTES_20, _publicKey);
    }

    function getTimelockScript(uint32 _blocks, bytes32 _publicKey) internal pure returns (bytes memory) {
        // If _blocks number have passed since this transaction has been confirmed,
        // the timelocked public key can spend the funds
        return abi.encodePacked(
            _blocks,
            OpCodes.OP_CHECKSEQUENCEVERIFY, // OP_CSV
            OpCodes.OP_DROP,
            _publicKey, // public key is the 32-byte x-coordinate only.
            OpCodes.OP_CHECKSIG
        );
    }

    /// @dev https://learnmeabitcoin.com/technical/upgrades/taproot/#script-tree-merkle-root-leaf-hash
    function getLeaf(bytes memory _script) internal pure returns (bytes32) {
        bytes memory data = abi.encodePacked(LEAF_VERSION, BtcHelper.toCompactSize(_script.length), _script);
        return BtcHelper.taggedHash(TAP_LEAF, data);
    }

    /// @dev https://learnmeabitcoin.com/technical/upgrades/taproot/#script-tree-merkle-root-branch-hash
    function getBranch(bytes32 _aLeafOrBranch, bytes32 _anotherLeafOrBranch) internal pure returns (bytes32) {
        bytes32 lowerHash = _aLeafOrBranch;
        bytes32 higherHash = _anotherLeafOrBranch;
        if (_aLeafOrBranch > _anotherLeafOrBranch) {
            lowerHash = _anotherLeafOrBranch;
            higherHash = _aLeafOrBranch;
        }
        bytes memory data = abi.encodePacked(lowerHash, higherHash);
        return BtcHelper.taggedHash(TAP_BRANCH, data);
    }
}
