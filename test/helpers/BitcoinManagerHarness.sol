// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BitcoinManager} from "src/BitcoinManager.sol";

/// @title BitcoinManagerHarness
/// @notice Test harness to expose internal functions for testing
contract BitcoinManagerHarness is BitcoinManager {
    /// @notice Exposes the internal _buildMerkleTreeFromLeaves function for testing
    function buildMerkleTreeFromLeaves(bytes32[] memory leaves) external pure returns (bytes32) {
        return _buildMerkleTreeFromLeaves(leaves);
    }

    /// @notice Exposes the internal _getVerifyKeyLeaves function for testing
    function getVerifyKeyLeaves(bytes32[] calldata disputeKeys) external pure returns (bytes32[] memory) {
        return _getVerifyKeyLeaves(disputeKeys);
    }

    /// @notice Exposes the internal _getEnablerOutputTweakedPublicKey function for testing
    function getEnablerOutputTweakedPublicKey(bytes calldata committeePubKey, bytes32[] calldata disputeKeys)
        external
        pure
        returns (bytes32)
    {
        return _getEnablerOutputTweakedPublicKey(committeePubKey, disputeKeys);
    }
}
