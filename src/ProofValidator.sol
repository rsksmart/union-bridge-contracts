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

/// @title Proof Validator
/// @notice Simple proof validator for proving Bitcoin transactions in RSK
/// @dev Provides functionality to verify Bitcoin transaction confirmations using the RSK Bridge
/// @dev Uses the RSK Bridge precompiled contract to validate transaction proofs
abstract contract ProofValidator is Initializable {
    /// @notice The RSK Bridge contract used for Bitcoin transaction verification
    /// @dev This contract provides access to Bitcoin transaction confirmation data
    IBridge public bridge;

    // Errors
    /// @notice Error thrown when the provided Bitcoin block hash doesn't exist
    /// @param blockHash The non-existent block hash that was provided
    error BridgeBtcInexistantBlockHash(bytes32 blockHash);

    /// @notice Error thrown when the provided Bitcoin block is not in the best chain
    /// @param blockHash The block hash that is not in the best chain
    error BridgeBtcBlockNotInBestChain(bytes32 blockHash);

    /// @notice Error thrown when the provided Bitcoin block data is inconsistent
    /// @param blockHash The block hash with inconsistent data
    error BridgeBtcInconsistentBlock(bytes32 blockHash);

    /// @notice Error thrown when the provided Bitcoin block is too old (> 1 month)
    /// @param maxDepth The maximum allowed depth for block retrieval
    error BridgeBtcBlockTooOld(int256 maxDepth);

    /// @notice Error thrown when the merkle proof for a Bitcoin transaction is invalid
    /// @param txid The transaction id that failed merkle proof verification
    /// @param merkleBranchPath The merkle branch path that was used
    /// @param merkleBranchHashes The merkle branch hashes that were provided
    error BridgeBtcTxInvalidMerkleBranch(bytes32 txid, uint256 merkleBranchPath, bytes32[] merkleBranchHashes);

    /// @notice Error thrown when the RSK Bridge returns an unknown error code
    /// @param errorCode The unknown error code returned by the bridge
    error BridgeBtcUnknownError(int256 errorCode);

    /// @notice Error thrown when a transaction doesn't have enough confirmations
    /// @param actual The actual number of confirmations the transaction has
    /// @param expected The minimum number of confirmations required
    error NotEnoughConfirmations(int256 actual, uint256 expected);

    /// @notice Error thrown when the bridge address is set to zero
    error BridgeAddressZero();

    /// @notice Initializes the ProofValidator contract
    /// @dev Sets up the RSK Bridge address for Bitcoin transaction verification
    /// @dev Can only be called once during contract deployment
    /// @param _bridgeAddress The address of the RSK Bridge contract
    function __ProofValidator_init(address payable _bridgeAddress) internal initializer {
        if (_bridgeAddress == address(0)) {
            revert BridgeAddressZero();
        }
        bridge = IBridge(_bridgeAddress);
    }

    /// @notice Verifies that a Bitcoin transaction exists in a block and has enough confirmations
    /// @param _minConfirmations The minimum number of confirmations required for the transaction
    /// @param _txid The hash of the Bitcoin transaction to verify
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
    function _verifyTxConfirmations(
        uint256 _minConfirmations,
        bytes32 _txid,
        bytes32 _blockHash,
        uint256 _merkleBranchPath,
        bytes32[] memory _merkleBranchHashes
    ) internal view {
        // Get tx confirmations using ProofValidator from Rsk bridge precompiled contract
        int256 confirmations =
            bridge.getBtcTransactionConfirmations(_txid, _blockHash, _merkleBranchPath, _merkleBranchHashes);
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
            revert BridgeBtcTxInvalidMerkleBranch(_txid, _merkleBranchPath, _merkleBranchHashes);
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
