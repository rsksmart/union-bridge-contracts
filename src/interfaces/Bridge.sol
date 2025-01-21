// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

address payable constant RSK_BRIDGE_ADDRESS = payable(0x0000000000000000000000000000000001000006);

// Enough depth to be able to search backwards one month worth of blocks
// (6 blocks/hour, 24 hours/day, 30 days/month)
int256 constant BTC_TRANSACTION_CONFIRMATION_MAX_DEPTH = 4320;
// From https://github.com/rsksmart/rskj/blob/master/rskj-core/src/main/java/co/rsk/peg/BridgeSupport.java#L89C1-L93C100
int256 constant BTC_TRANSACTION_CONFIRMATION_INEXISTENT_BLOCK_HASH_ERROR_CODE = -1;
int256 constant BTC_TRANSACTION_CONFIRMATION_BLOCK_NOT_IN_BEST_CHAIN_ERROR_CODE = -2;
int256 constant BTC_TRANSACTION_CONFIRMATION_INCONSISTENT_BLOCK_ERROR_CODE = -3;
int256 constant BTC_TRANSACTION_CONFIRMATION_BLOCK_TOO_OLD_ERROR_CODE = -4;
int256 constant BTC_TRANSACTION_CONFIRMATION_INVALID_MERKLE_BRANCH_ERROR_CODE = -5;

interface Bridge {
    receive() external payable;

    function getBtcBlockchainBestChainHeight() external view returns (int256);

    function getStateForBtcReleaseClient() external view returns (bytes memory);

    function getStateForDebugging() external view returns (bytes memory);

    function getBtcBlockchainInitialBlockHeight() external view returns (int256);

    function getBtcBlockchainBlockHashAtDepth(int256 depth) external view returns (bytes memory);

    function getBtcTxHashProcessedHeight(string calldata hash) external view returns (int64);

    function isBtcTxHashAlreadyProcessed(string calldata hash) external view returns (bool);

    function getFederationAddress() external view returns (string memory);

    function registerBtcTransaction(bytes calldata atx, int256 height, bytes calldata pmt) external;

    function addSignature(bytes calldata pubkey, bytes[] calldata signatures, bytes calldata txhash) external;

    function receiveHeaders(bytes[] calldata blocks) external;

    function receiveHeader(bytes calldata ablock) external returns (int256);

    function getFederationSize() external view returns (int256);

    function getFederationThreshold() external view returns (int256);

    function getFederatorPublicKey(int256 index) external view returns (bytes memory);

    function getFederatorPublicKeyOfType(int256 index, string calldata atype) external returns (bytes memory);

    function getFederationCreationTime() external view returns (int256);

    function getFederationCreationBlockNumber() external view returns (int256);

    function getRetiringFederationAddress() external view returns (string memory);

    function getRetiringFederationSize() external view returns (int256);

    function getRetiringFederationThreshold() external view returns (int256);

    function getRetiringFederatorPublicKey(int256 index) external view returns (bytes memory);

    function getRetiringFederatorPublicKeyOfType(int256 index, string calldata atype)
        external
        view
        returns (bytes memory);

    function getRetiringFederationCreationTime() external view returns (int256);

    function getRetiringFederationCreationBlockNumber() external view returns (int256);

    function createFederation() external returns (int256);

    function addFederatorPublicKey(bytes calldata key) external returns (int256);

    function addFederatorPublicKeyMultikey(bytes calldata btcKey, bytes calldata rskKey, bytes calldata mstKey)
        external
        returns (int256);

    function commitFederation(bytes calldata hash) external returns (int256);

    function rollbackFederation() external returns (int256);

    function getPendingFederationHash() external view returns (bytes memory);

    function getPendingFederationSize() external view returns (int256);

    function getPendingFederatorPublicKey(int256 index) external view returns (bytes memory);

    function getPendingFederatorPublicKeyOfType(int256 index, string calldata atype)
        external
        view
        returns (bytes memory);

    function getLockWhitelistSize() external view returns (int256);

    function getLockWhitelistAddress(int256 index) external view returns (string memory);

    function getLockWhitelistEntryByAddress(string calldata aaddress) external view returns (int256);

    function addLockWhitelistAddress(string calldata aaddress, int256 maxTransferValue) external returns (int256);

    function addOneOffLockWhitelistAddress(string calldata aaddress, int256 maxTransferValue)
        external
        returns (int256);

    function addUnlimitedLockWhitelistAddress(string calldata aaddress) external returns (int256);

    function removeLockWhitelistAddress(string calldata aaddress) external returns (int256);

    function setLockWhitelistDisableBlockDelay(int256 disableDelay) external returns (int256);

    function getFeePerKb() external view returns (int256);

    function voteFeePerKbChange(int256 feePerKb) external returns (int256);

    function updateCollections() external;

    function getMinimumLockTxValue() external view returns (int256);

    function getBtcTransactionConfirmations(
        bytes32 txHash,
        bytes32 blockHash,
        uint256 merkleBranchPath,
        bytes32[] calldata merkleBranchHashes
    ) external view returns (int256);

    function getLockingCap() external view returns (int256);

    function increaseLockingCap(int256 newLockingCap) external returns (bool);

    function registerBtcCoinbaseTransaction(
        bytes calldata btcTxSerialized,
        bytes32 blockHash,
        bytes calldata pmtSerialized,
        bytes32 witnessMerkleRoot,
        bytes32 witnessReservedValue
    ) external;

    function hasBtcBlockCoinbaseTransactionInformation(bytes32 blockHash) external returns (bool);

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

    function getActiveFederationCreationBlockHeight() external view returns (uint256);

    function getActivePowpegRedeemScript() external view returns (bytes memory);

    function getBtcBlockchainBestBlockHeader() external view returns (bytes memory);

    function getBtcBlockchainBlockHeaderByHash(bytes32 btcBlockHash) external view returns (bytes memory);

    function getBtcBlockchainBlockHeaderByHeight(uint256 btcBlockHeight) external view returns (bytes memory);

    function getBtcBlockchainParentBlockHeaderByHash(bytes32 btcBlockHash) external view returns (bytes memory);
}
