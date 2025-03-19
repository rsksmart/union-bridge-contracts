// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {
    IBridge,
    BTC_TRANSACTION_CONFIRMATION_MAX_DEPTH,
    BTC_TRANSACTION_CONFIRMATION_INEXISTENT_BLOCK_HASH_ERROR_CODE,
    BTC_TRANSACTION_CONFIRMATION_BLOCK_NOT_IN_BEST_CHAIN_ERROR_CODE,
    BTC_TRANSACTION_CONFIRMATION_INCONSISTENT_BLOCK_ERROR_CODE,
    BTC_TRANSACTION_CONFIRMATION_BLOCK_TOO_OLD_ERROR_CODE,
    BTC_TRANSACTION_CONFIRMATION_INVALID_MERKLE_BRANCH_ERROR_CODE
} from "./interfaces/IBridge.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/// @title ProofValidator
/// @notice Simple proof validator for proving Bitcoin Tx in RSK
abstract contract ProofValidator is Initializable {
    IBridge public bridge;

    error BridgeBtcInexistantBlockHash(bytes32 blockHash);
    error BridgeBtcBlockNotInBestChain(bytes32 blockHash);
    error BridgeBtcInconsistentBlock(bytes32 blockHash);
    error BridgeBtcBlockTooOld(int256 maxDepth);
    error BridgeBtcTxInvalidMerkleBranch(bytes32 txHash, uint256 merkleBranchPath, bytes32[] merkleBranchHashes);
    error BridgeBtcUnknownError(int256 errorCode);
    error NotEnoughConfirmations(int256 actual, uint256 expected);
    error BridgeAddressZero();

    function __ProofValidator_init(address payable _bridgeAddress) public initializer {
        if (_bridgeAddress == address(0)) {
            revert BridgeAddressZero();
        }
        bridge = IBridge(_bridgeAddress);
    }

    /// @notice Verifies that a Bitcoin transaction exists in a block and has enough confirmations
    /// @param _minConfirmations The minimum number of confirmations required for the transaction
    /// @param _txHash The hash of the Bitcoin transaction to verify
    /// @param _blockHash The hash of the block containing the transaction
    /// @param _merkleBranchPath The path in the merkle tree to verify the transaction
    /// @param _merkleBranchHashes The hashes needed to verify the merkle proof
    /// @dev Uses RSK bridge precompiled contract to verify the transaction via ProofValidator
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
        // Get tx confirmations using ProofValidator from Rsk bridge precompiled contract
        int256 confirmations =
            bridge.getBtcTransactionConfirmations(_txHash, _blockHash, _merkleBranchPath, _merkleBranchHashes);
        // Validate block is in the Mainchain
        if (confirmations == BTC_TRANSACTION_CONFIRMATION_INEXISTENT_BLOCK_HASH_ERROR_CODE) {
            revert BridgeBtcInexistantBlockHash(_blockHash);
        }
        if (confirmations == BTC_TRANSACTION_CONFIRMATION_BLOCK_NOT_IN_BEST_CHAIN_ERROR_CODE) {
            revert BridgeBtcBlockNotInBestChain(_blockHash);
        }
        if (confirmations == BTC_TRANSACTION_CONFIRMATION_INCONSISTENT_BLOCK_ERROR_CODE) {
            revert BridgeBtcInconsistentBlock(_blockHash);
        }
        // Rsk only allows to retrieve blocks up to 1 month
        if (confirmations == BTC_TRANSACTION_CONFIRMATION_BLOCK_TOO_OLD_ERROR_CODE) {
            revert BridgeBtcBlockTooOld(BTC_TRANSACTION_CONFIRMATION_MAX_DEPTH);
        }
        // Validate transaction is in the Block
        if (confirmations == BTC_TRANSACTION_CONFIRMATION_INVALID_MERKLE_BRANCH_ERROR_CODE) {
            revert BridgeBtcTxInvalidMerkleBranch(_txHash, _merkleBranchPath, _merkleBranchHashes);
        }
        if (confirmations < 0) {
            revert BridgeBtcUnknownError(confirmations);
        }

        // Validate block has enough Confirmations
        if (uint256(confirmations) < _minConfirmations) {
            revert NotEnoughConfirmations(confirmations, _minConfirmations);
        }
    }
}
