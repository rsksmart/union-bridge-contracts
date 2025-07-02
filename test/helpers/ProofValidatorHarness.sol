// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ProofValidator} from "src/ProofValidator.sol";

/// @title SPVHarness
/// @notice Wrapper for testing ProofValidator
contract ProofValidatorHarness is ProofValidator {
    function verifyTxConfirmationsHarness(
        uint256 _minConfirmations,
        bytes32 _txHash,
        bytes32 _blockHash,
        uint256 _merkleBranchPath,
        bytes32[] memory _merkleBranchHashes
    ) external view {
        _verifyTxConfirmations(_minConfirmations, _txHash, _blockHash, _merkleBranchPath, _merkleBranchHashes);
    }
}
