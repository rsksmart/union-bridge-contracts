// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @dev The RSK Bridge contract address for pow-peg bridge operations
/// @dev This is the address of the RSK Bridge contract that handles pow-peg operations
address payable constant RSK_BRIDGE_ADDRESS = payable(0x0000000000000000000000000000000001000006);

/// @dev Maximum depth for Bitcoin transaction confirmation searches
/// @dev Enough depth to search backwards one month worth of blocks
/// @dev (6 blocks/hour, 24 hours/day, 30 days/month)
int256 constant BTC_TRANSACTION_CONFIRMATION_MAX_DEPTH = 4320;

/// @dev Error code for non-existent block hash in Bitcoin transaction confirmation
/// @dev From RSK Bridge implementation https://github.com/rsksmart/rskj/blob/master/rskj-core/src/main/java/co/rsk/peg/BridgeSupport.java#L89C1-LL93C100
int256 constant BTC_TRANSACTION_CONFIRMATION_INEXISTENT_BLOCK_HASH_ERROR_CODE = -1;

/// @dev Error code for block not in best chain in Bitcoin transaction confirmation
/// @dev From RSK Bridge implementation https://github.com/rsksmart/rskj/blob/master/rskj-core/src/main/java/co/rsk/peg/BridgeSupport.java#L89C1-LL93C100
int256 constant BTC_TRANSACTION_CONFIRMATION_BLOCK_NOT_IN_BEST_CHAIN_ERROR_CODE = -2;

/// @dev Error code for inconsistent block in Bitcoin transaction confirmation
/// @dev From RSK Bridge implementation https://github.com/rsksmart/rskj/blob/master/rskj-core/src/main/java/co/rsk/peg/BridgeSupport.java#L89C1-LL93C100
int256 constant BTC_TRANSACTION_CONFIRMATION_INCONSISTENT_BLOCK_ERROR_CODE = -3;

/// @dev Error code for block too old in Bitcoin transaction confirmation
/// @dev From RSK Bridge implementation https://github.com/rsksmart/rskj/blob/master/rskj-core/src/main/java/co/rsk/peg/BridgeSupport.java#L89C1-LL93C100
int256 constant BTC_TRANSACTION_CONFIRMATION_BLOCK_TOO_OLD_ERROR_CODE = -4;

/// @dev Error code for invalid merkle branch in Bitcoin transaction confirmation
/// @dev From RSK Bridge implementation https://github.com/rsksmart/rskj/blob/master/rskj-core/src/main/java/co/rsk/peg/BridgeSupport.java#L89C1-LL93C100
int256 constant BTC_TRANSACTION_CONFIRMATION_INVALID_MERKLE_BRANCH_ERROR_CODE = -5;

/// @notice Interface for interacting with the RSK pow-peg Bridge contract
/// @dev This interface provides functions for pow-peg bridge operations and Bitcoin transaction validation
/// @dev Used for compatibility with the existing RSK Bridge system
interface IBridge {
    /// @notice Allows the contract to receive RBTC
    /// @dev Enables the contract to receive RBTC transfers
    receive() external payable;

    /// @notice Requests Union RBTC from the bridge
    /// @param amount The amount of Union RBTC to request
    /// @return The result code of the operation
    function requestUnionRBTC(uint256 amount) external returns (int256);

    /// @notice Gets the current best chain height of the Bitcoin blockchain
    /// @return The current best chain height
    function getBtcBlockchainBestChainHeight() external view returns (int256);

    /// @notice Gets the state for BTC release client operations
    /// @return The state data for BTC release client
    function getStateForBtcReleaseClient() external view returns (bytes memory);

    /// @notice Gets the state for debugging purposes
    /// @return The debug state data
    function getStateForDebugging() external view returns (bytes memory);

    /// @dev This method throws an OOG because cannot be called inside the blockchain https://ips.rootstock.io/IPs/RSKIP89.html
    /// @notice Gets the initial block height of the Bitcoin blockchain
    /// @return The initial block height
    /// function getBtcBlockchainInitialBlockHeight() external view returns (int256);

    /// @dev This method throws an OOG because cannot be called inside the blockchain https://ips.rootstock.io/IPs/RSKIP89.html
    /// @notice Gets the Bitcoin blockchain block hash at a specific depth
    /// @param depth The depth from the current best chain
    /// @return The block hash at the specified depth
    /// function getBtcBlockchainBlockHashAtDepth(int256 depth) external view returns (bytes memory);

    /// @notice Gets the processed height for a Bitcoin transaction hash
    /// @param hash The Bitcoin transaction hash
    /// @return The processed height for the transaction
    function getBtcTxHashProcessedHeight(string calldata hash) external view returns (int64);

    /// @notice Checks if a Bitcoin transaction hash has already been processed
    /// @param hash The Bitcoin transaction hash to check
    /// @return True if the transaction has already been processed
    function isBtcTxHashAlreadyProcessed(string calldata hash) external view returns (bool);

    /// @notice Gets the federation address
    /// @return The federation address
    function getFederationAddress() external view returns (string memory);

    /// @notice Registers a Bitcoin transaction
    /// @param atx The serialized Bitcoin transaction
    /// @param height The block height where the transaction was included
    /// @param pmt The partial merkle tree proof
    function registerBtcTransaction(bytes calldata atx, int256 height, bytes calldata pmt) external;

    /// @notice Adds a signature for a transaction
    /// @param pubkey The public key of the signer
    /// @param signatures Array of signatures
    /// @param txhash The transaction hash
    function addSignature(bytes calldata pubkey, bytes[] calldata signatures, bytes calldata txhash) external;

    /// @notice Receives multiple block headers
    /// @param blocks Array of serialized block headers
    function receiveHeaders(bytes[] calldata blocks) external;

    /// @notice Receives a single block header
    /// @param ablock The serialized block header
    /// @return The result code of the operation
    function receiveHeader(bytes calldata ablock) external returns (int256);

    /// @notice Gets the size of the federation
    /// @return The number of federators in the federation
    function getFederationSize() external view returns (int256);

    /// @notice Gets the threshold required for federation operations
    /// @return The threshold number of federators required
    function getFederationThreshold() external view returns (int256);

    /// @notice Gets the public key of a federator by index
    /// @param index The index of the federator
    /// @return The public key of the federator
    function getFederatorPublicKey(int256 index) external view returns (bytes memory);

    /// @notice Gets the public key of a specific type for a federator
    /// @param index The index of the federator
    /// @param atype The type of public key to retrieve
    /// @return The public key of the specified type
    function getFederatorPublicKeyOfType(int256 index, string calldata atype) external returns (bytes memory);

    /// @notice Gets the creation time of the federation
    /// @return The timestamp when the federation was created
    function getFederationCreationTime() external view returns (int256);

    /// @notice Gets the creation block number of the federation
    /// @return The block number when the federation was created
    function getFederationCreationBlockNumber() external view returns (int256);

    /// @notice Gets the address of the retiring federation
    /// @return The retiring federation address
    function getRetiringFederationAddress() external view returns (string memory);

    /// @notice Gets the size of the retiring federation
    /// @return The number of federators in the retiring federation
    function getRetiringFederationSize() external view returns (int256);

    /// @notice Gets the threshold required for retiring federation operations
    /// @return The threshold number of federators required for retiring federation
    function getRetiringFederationThreshold() external view returns (int256);

    /// @notice Gets the public key of a retiring federator by index
    /// @param index The index of the retiring federator
    /// @return The public key of the retiring federator
    function getRetiringFederatorPublicKey(int256 index) external view returns (bytes memory);

    /// @notice Gets the public key of a specific type for a retiring federator
    /// @param index The index of the retiring federator
    /// @param atype The type of public key to retrieve
    /// @return The public key of the specified type for the retiring federator
    function getRetiringFederatorPublicKeyOfType(int256 index, string calldata atype)
        external
        view
        returns (bytes memory);

    /// @notice Gets the creation time of the retiring federation
    /// @return The timestamp when the retiring federation was created
    function getRetiringFederationCreationTime() external view returns (int256);

    /// @notice Gets the creation block number of the retiring federation
    /// @return The block number when the retiring federation was created
    function getRetiringFederationCreationBlockNumber() external view returns (int256);

    /// @notice Creates a new federation
    /// @return The result code of the operation
    function createFederation() external returns (int256);

    /// @notice Adds a federator public key
    /// @param key The public key to add
    /// @return The result code of the operation
    function addFederatorPublicKey(bytes calldata key) external returns (int256);

    /// @notice Adds a federator public key with multiple key types
    /// @param btcKey The Bitcoin public key
    /// @param rskKey The RSK public key
    /// @param mstKey The MST public key
    /// @return The result code of the operation
    function addFederatorPublicKeyMultikey(bytes calldata btcKey, bytes calldata rskKey, bytes calldata mstKey)
        external
        returns (int256);

    /// @notice Commits a federation with a specific hash
    /// @param hash The hash to commit
    /// @return The result code of the operation
    function commitFederation(bytes calldata hash) external returns (int256);

    /// @notice Rolls back the federation
    /// @return The result code of the operation
    function rollbackFederation() external returns (int256);

    /// @notice Gets the hash of the pending federation
    /// @return The hash of the pending federation
    function getPendingFederationHash() external view returns (bytes memory);

    /// @notice Gets the size of the pending federation
    /// @return The number of federators in the pending federation
    function getPendingFederationSize() external view returns (int256);

    /// @notice Gets the public key of a pending federator by index
    /// @param index The index of the pending federator
    /// @return The public key of the pending federator
    function getPendingFederatorPublicKey(int256 index) external view returns (bytes memory);

    /// @notice Gets the public key of a specific type for a pending federator
    /// @param index The index of the pending federator
    /// @param atype The type of public key to retrieve
    /// @return The public key of the specified type for the pending federator
    function getPendingFederatorPublicKeyOfType(int256 index, string calldata atype)
        external
        view
        returns (bytes memory);

    /// @notice Gets the size of the lock whitelist
    /// @return The number of addresses in the lock whitelist
    function getLockWhitelistSize() external view returns (int256);

    /// @notice Gets a lock whitelist address by index
    /// @param index The index of the whitelist entry
    /// @return The whitelisted address
    function getLockWhitelistAddress(int256 index) external view returns (string memory);

    /// @notice Gets a lock whitelist entry by address
    /// @param aaddress The address to look up
    /// @return The index of the whitelist entry
    function getLockWhitelistEntryByAddress(string calldata aaddress) external view returns (int256);

    /// @notice Adds an address to the lock whitelist
    /// @param aaddress The address to add
    /// @param maxTransferValue The maximum transfer value allowed
    /// @return The result code of the operation
    function addLockWhitelistAddress(string calldata aaddress, int256 maxTransferValue) external returns (int256);

    /// @notice Adds a one-off address to the lock whitelist
    /// @param aaddress The address to add
    /// @param maxTransferValue The maximum transfer value allowed
    /// @return The result code of the operation
    function addOneOffLockWhitelistAddress(string calldata aaddress, int256 maxTransferValue)
        external
        returns (int256);

    /// @notice Adds an address with unlimited transfer value to the lock whitelist
    /// @param aaddress The address to add
    /// @return The result code of the operation
    function addUnlimitedLockWhitelistAddress(string calldata aaddress) external returns (int256);

    /// @notice Removes an address from the lock whitelist
    /// @param aaddress The address to remove
    /// @return The result code of the operation
    function removeLockWhitelistAddress(string calldata aaddress) external returns (int256);

    /// @notice Sets the block delay for disabling the lock whitelist
    /// @param disableDelay The delay in blocks
    /// @return The result code of the operation
    function setLockWhitelistDisableBlockDelay(int256 disableDelay) external returns (int256);

    /// @notice Gets the fee per kilobyte for transactions
    /// @return The fee per kilobyte in satoshis
    function getFeePerKb() external view returns (int256);

    /// @notice Votes for a change in the fee per kilobyte
    /// @param feePerKb The new fee per kilobyte to vote for
    /// @return The result code of the operation
    function voteFeePerKbChange(int256 feePerKb) external returns (int256);

    /// @notice Updates collections
    function updateCollections() external;

    /// @notice Gets the minimum lock transaction value
    /// @return The minimum value required for lock transactions
    function getMinimumLockTxValue() external view returns (int256);

    /// @notice Gets the number of confirmations for a Bitcoin transaction
    /// @param txHash The Bitcoin transaction hash
    /// @param blockHash The block hash containing the transaction
    /// @param merkleBranchPath The merkle branch path
    /// @param merkleBranchHashes Array of merkle branch hashes
    /// @return The number of confirmations or error code
    function getBtcTransactionConfirmations(
        bytes32 txHash,
        bytes32 blockHash,
        uint256 merkleBranchPath,
        bytes32[] calldata merkleBranchHashes
    ) external view returns (int256);

    /// @notice Gets the current locking cap
    /// @return The maximum amount that can be locked
    function getLockingCap() external view returns (int256);

    /// @notice Increases the locking cap
    /// @param newLockingCap The new locking cap value
    /// @return True if the operation was successful
    function increaseLockingCap(int256 newLockingCap) external returns (bool);

    /// @notice Registers a Bitcoin coinbase transaction
    /// @param btcTxSerialized The serialized Bitcoin transaction
    /// @param blockHash The block hash containing the transaction
    /// @param pmtSerialized The serialized partial merkle tree
    /// @param witnessMerkleRoot The witness merkle root
    /// @param witnessReservedValue The witness reserved value
    function registerBtcCoinbaseTransaction(
        bytes calldata btcTxSerialized,
        bytes32 blockHash,
        bytes calldata pmtSerialized,
        bytes32 witnessMerkleRoot,
        bytes32 witnessReservedValue
    ) external;

    /// @notice Checks if a Bitcoin block has coinbase transaction information
    /// @param blockHash The block hash to check
    /// @return True if the block has coinbase transaction information
    function hasBtcBlockCoinbaseTransactionInformation(bytes32 blockHash) external returns (bool);

    /// @notice Registers a fast bridge Bitcoin transaction
    /// @param btcTxSerialized The serialized Bitcoin transaction
    /// @param height The block height
    /// @param pmtSerialized The serialized partial merkle tree
    /// @param derivationArgumentsHash The hash of derivation arguments
    /// @param userRefundBtcAddress The user's refund Bitcoin address
    /// @param liquidityBridgeContractAddress The liquidity bridge contract address
    /// @param liquidityProviderBtcAddress The liquidity provider's Bitcoin address
    /// @param shouldTransferToContract Whether to transfer to the contract
    /// @return The result code of the operation
    function registerFastBridgeBtcTransaction(
        bytes calldata btcTxSerialized,
        uint256 height,
        bytes calldata pmtSerialized,
        bytes32 derivationArgumentsHash,
        bytes calldata userRefundBtcAddress,
        address payable liquidityBridgeContractAddress,
        bytes calldata liquidityProviderBtcAddress,
        bool shouldTransferToContract
    ) external returns (int256);

    /// @notice Gets the active federation creation block height
    /// @return The block height when the active federation was created
    function getActiveFederationCreationBlockHeight() external view returns (uint256);

    /// @notice Gets the active Powpeg redeem script
    /// @return The active Powpeg redeem script
    function getActivePowpegRedeemScript() external view returns (bytes memory);

    /// @notice Gets the best block header of the Bitcoin blockchain
    /// @return The serialized best block header
    function getBtcBlockchainBestBlockHeader() external view returns (bytes memory);

    /// @notice Gets a Bitcoin blockchain block header by hash
    /// @param btcBlockHash The Bitcoin block hash
    /// @return The serialized block header
    function getBtcBlockchainBlockHeaderByHash(bytes32 btcBlockHash) external view returns (bytes memory);

    /// @notice Gets a Bitcoin blockchain block header by height
    /// @param btcBlockHeight The Bitcoin block height
    /// @return The serialized block header
    function getBtcBlockchainBlockHeaderByHeight(uint256 btcBlockHeight) external view returns (bytes memory);

    /// @notice Gets the parent block header of a Bitcoin block by hash
    /// @param btcBlockHash The Bitcoin block hash
    /// @return The serialized parent block header
    function getBtcBlockchainParentBlockHeaderByHash(bytes32 btcBlockHash) external view returns (bytes memory);
}
