// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {IBridge} from "./IBridge.sol";

/// @title IRbtcBridge
/// @notice Interface for the RbtcBridge contract that acts as the single authorized intermediary
///         between the Union Bridge system and the RSK PowPeg Bridge for RBTC minting/burning operations
/// @dev This contract is required because RSKIP-502 only allows ONE contract address to be authorized
///      for minting and burning RBTC from the PowPeg bridge. Since PegManager is split into
///      PeginManager and PegoutManager, we need this intermediary to be the single authorized address.
interface IRbtcBridge {
    // ===================== Functions =====================

    /// @notice Gets the RSK pow-peg Bridge contract
    /// @return The RSK PowPeg Bridge contract
    function bridge() external view returns (IBridge);

    /// @notice Mints RBTC from the PowPeg bridge and sends it to the specified address
    /// @param _to The address to receive the minted RBTC
    /// @param _amount The amount of RBTC to mint in wei
    /// @dev Only callable by the peginManager when contract is not paused
    /// @dev Requests RBTC from PowPeg bridge via requestUnionBridgeRbtc
    /// @dev Transfers RBTC to recipient with 100k gas limit
    function mintRbtc(address payable _to, uint256 _amount) external;

    /// @notice Burns RBTC back to the PowPeg bridge
    /// @dev Only callable by the pegoutManager when contract is not paused
    /// @dev The pegoutManager must send the RBTC amount via msg.value
    /// @dev Returns RBTC to PowPeg bridge via releaseUnionBridgeRbtc
    function burnRbtc() external payable;

    /// @notice Gets the locking cap of the Union Bridge for RBTC minting operations
    /// @return unionBridgeLockingCap The locking cap of the Union Bridge
    function getUnionBridgeLockingCap() external view returns (uint256 unionBridgeLockingCap);

    /// @notice Gets the hash of the best block in the Bitcoin blockchain
    /// @return bestBlockHash The hash of the best block in the Bitcoin blockchain
    function getBestBlockHash() external view returns (bytes32 bestBlockHash);

    /// @notice Verifies that a Bitcoin transaction exists in a block and has enough confirmations
    /// @param _minConfirmations The minimum number of confirmations required for the transaction
    /// @param _txid The hash of the Bitcoin transaction to verify
    /// @param _blockHash The hash of the block containing the transaction
    /// @param _merkleBranchPath The path in the merkle tree to verify the transaction
    /// @param _merkleBranchHashes The hashes needed to verify the merkle proof
    /// @dev Uses RSK bridge precompiled contract to verify the transaction
    /// @dev Will revert if:
    ///      - Block hash doesn't exist
    ///      - Block is not in best chain
    ///      - Block data is inconsistent
    ///      - Block is too old (> 1 month)
    ///      - Merkle proof is invalid
    ///      - Not enough confirmations
    function verifyTxConfirmations(
        uint256 _minConfirmations,
        bytes32 _txid,
        bytes32 _blockHash,
        uint256 _merkleBranchPath,
        bytes32[] memory _merkleBranchHashes
    ) external view;

    /// @notice Verifies that a Bitcoin transaction exists in a block and has enough confirmations
    /// @param _minConfirmations The minimum number of confirmations required for the transaction
    /// @param _txid The hash of the Bitcoin transaction to verify
    /// @param _blockHash The hash of the block containing the transaction
    /// @param _merkleBranchPath The path in the merkle tree to verify the transaction
    /// @param _merkleBranchHashes The hashes needed to verify the merkle proof
    /// @return blockNumber The block number of the transaction
    /// @dev Uses RSK bridge precompiled contract to verify the transaction
    /// @dev Will revert if:
    ///      - Block hash doesn't exist
    ///      - Block is not in best chain
    ///      - Block data is inconsistent
    ///      - Block is too old (> 1 month)
    ///      - Merkle proof is invalid
    ///      - Not enough confirmations
    function getTxBlockNumberAndVerifyConfirmations(
        uint256 _minConfirmations,
        bytes32 _txid,
        bytes32 _blockHash,
        uint256 _merkleBranchPath,
        bytes32[] memory _merkleBranchHashes
    ) external view returns (int256 blockNumber);

    // ===================== Events =====================

    /// @notice Emitted when RBTC is minted and sent to a user
    /// @param to The address that received the RBTC
    /// @param amount The amount of RBTC minted in wei
    event RbtcMinted(address indexed to, uint256 amount);

    /// @notice Emitted when RBTC is burned back to the PowPeg bridge
    /// @param amount The amount of RBTC burned in wei
    event RbtcBurned(uint256 amount);

    // ===================== Errors =====================

    /// @notice Thrown when an unauthorized address attempts to call a restricted function
    /// @param caller The address that attempted the unauthorized call
    error UnauthorizedCaller(address caller);

    /// @notice Thrown when RBTC transfer to recipient fails
    /// @param to The intended recipient address
    /// @param amount The amount that failed to transfer
    error FailedToSendRBTC(address to, uint256 amount);

    /// @notice Thrown when the PowPeg bridge rejects the request due to unauthorized caller (error code -1)
    error BridgeUnauthorizedCaller();

    /// @notice Thrown when the requested amount exceeds the PowPeg bridge locking cap (error code -2)
    /// @param amount The amount that exceeded the cap
    error BridgeExceededLockingCap(uint256 amount);

    /// @notice Thrown when RBTC transfers are currently disabled in the PowPeg bridge (error code -3)
    error BridgeTransfersDisabled();

    /// @notice Thrown when the burn amount exceeds the previously minted amount (error code -2)
    /// @param amount The invalid burn amount
    error BridgeReleaseInvalidValue(uint256 amount);

    /// @notice Thrown when the PowPeg bridge returns an unknown error code
    /// @param errorCode The error code returned by the bridge
    error BridgeBtcUnknownError(int256 errorCode);

    // ===================== Proof Validator Errors =====================

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

    /// @notice Error thrown when a transaction doesn't have enough confirmations
    /// @param actual The actual number of confirmations the transaction has
    /// @param expected The minimum number of confirmations required
    error NotEnoughConfirmations(int256 actual, uint256 expected);
}
