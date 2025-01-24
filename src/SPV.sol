// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {
    IBridge,
    RSK_BRIDGE_ADDRESS,
    BTC_TRANSACTION_CONFIRMATION_MAX_DEPTH,
    BTC_TRANSACTION_CONFIRMATION_INEXISTENT_BLOCK_HASH_ERROR_CODE,
    BTC_TRANSACTION_CONFIRMATION_BLOCK_NOT_IN_BEST_CHAIN_ERROR_CODE,
    BTC_TRANSACTION_CONFIRMATION_INCONSISTENT_BLOCK_ERROR_CODE,
    BTC_TRANSACTION_CONFIRMATION_BLOCK_TOO_OLD_ERROR_CODE,
    BTC_TRANSACTION_CONFIRMATION_INVALID_MERKLE_BRANCH_ERROR_CODE
} from "./interfaces/IBridge.sol";

/// @title SPV
/// @notice Simple proof validator for proving Bitcoin Tx in RSK
abstract contract SPV {
    error bridgeBtcInexistantBlockHash(bytes32 blockHash);
    error bridgeBtcBlockNotInBestChain(bytes32 blockHash);
    error bridgeBtcInconsistentBlock(bytes32 blockHash);
    error bridgeBtcBlockTooOld(int256 maxDepth);
    error bridgeBtcTxInvalidMerkleBranch(bytes32 txHash, uint256 merkleBranchPath, bytes32[] merkleBranchHashes);
    error bridgeBtcUnknownError(int256 errorCode);
    error notEnoughConfirmations(int256 actual, uint256 expected);

    /// @notice Verifies that a Bitcoin transaction exists in a block and has enough confirmations
    /// @param _minConfirmations The minimum number of confirmations required for the transaction
    /// @param _txHash The hash of the Bitcoin transaction to verify
    /// @param _blockHash The hash of the block containing the transaction
    /// @param _merkleBranchPath The path in the merkle tree to verify the transaction
    /// @param _merkleBranchHashes The hashes needed to verify the merkle proof
    /// @dev Uses RSK bridge precompiled contract to verify the transaction via SPV
    /// @dev Will revert if:
    ///      - Block hash doesn't exist
    ///      - Block is not in best chain
    ///      - Block data is inconsistent
    ///      - Block is too old (> 1 month)
    ///      - Merkle proof is invalid
    ///      - Not enough confirmations
    function verifyTxConfirmations(
        uint256 _minConfirmations,
        bytes32 _txHash,
        bytes32 _blockHash,
        uint256 _merkleBranchPath,
        bytes32[] memory _merkleBranchHashes
    ) internal view {
        // Get tx confirmations using SPV from Rsk bridge precompiled contract
        int256 confirmations = IBridge(RSK_BRIDGE_ADDRESS).getBtcTransactionConfirmations(
            _txHash, _blockHash, _merkleBranchPath, _merkleBranchHashes
        );
        // Validate block is in the Mainchain
        if (confirmations == BTC_TRANSACTION_CONFIRMATION_INEXISTENT_BLOCK_HASH_ERROR_CODE) {
            revert bridgeBtcInexistantBlockHash(_blockHash);
        }
        if (confirmations == BTC_TRANSACTION_CONFIRMATION_BLOCK_NOT_IN_BEST_CHAIN_ERROR_CODE) {
            revert bridgeBtcBlockNotInBestChain(_blockHash);
        }
        if (confirmations == BTC_TRANSACTION_CONFIRMATION_INCONSISTENT_BLOCK_ERROR_CODE) {
            revert bridgeBtcInconsistentBlock(_blockHash);
        }
        // Rsk only allows to retrieve blocks up to 1 month
        if (confirmations == BTC_TRANSACTION_CONFIRMATION_BLOCK_TOO_OLD_ERROR_CODE) {
            revert bridgeBtcBlockTooOld(BTC_TRANSACTION_CONFIRMATION_MAX_DEPTH);
        }
        // Validate transaction is in the Block
        if (confirmations == BTC_TRANSACTION_CONFIRMATION_INVALID_MERKLE_BRANCH_ERROR_CODE) {
            revert bridgeBtcTxInvalidMerkleBranch(_txHash, _merkleBranchPath, _merkleBranchHashes);
        }
        if (confirmations < 0) {
            revert bridgeBtcUnknownError(confirmations);
        }

        // Validate block has enough Confirmations
        if (confirmations < int256(_minConfirmations)) {
            revert notEnoughConfirmations(confirmations, _minConfirmations);
        }
    }
}
