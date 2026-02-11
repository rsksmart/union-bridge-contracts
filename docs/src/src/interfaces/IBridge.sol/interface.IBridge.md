# IBridge
[Git Source](https://github.com/temp-rsk/bitvmx-union-bridge-contracts/blob/6a9ea8ca3ca82c82894d3db0e338e4bf6bb46de8/src/interfaces/IBridge.sol)

Interface for interacting with the RSK pow-peg Bridge contract

*This interface provides functions for pow-peg bridge operations and Bitcoin transaction validation*

*Used for compatibility with the existing RSK Bridge system*


## Functions
### getBtcBlockchainBestChainHeight

Gets the current best chain height of the Bitcoin blockchain


```solidity
function getBtcBlockchainBestChainHeight() external view returns (int256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`int256`|The current best chain height|


### getStateForBtcReleaseClient

Gets the state for BTC release client operations


```solidity
function getStateForBtcReleaseClient() external view returns (bytes memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes`|The state data for BTC release client|


### getStateForDebugging

Gets the state for debugging purposes


```solidity
function getStateForDebugging() external view returns (bytes memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes`|The debug state data|


### getBtcTxHashProcessedHeight

Gets the initial block height of the Bitcoin blockchain

Gets the Bitcoin blockchain block hash at a specific depth

Gets the processed height for a Bitcoin transaction hash

*This method throws an OOG because it cannot be called inside the blockchain*

*See https://ips.rootstock.io/IPs/RSKIP89.html*

*This method throws an OOG because it cannot be called inside the blockchain*

*See https://ips.rootstock.io/IPs/RSKIP89.html*


```solidity
function getBtcTxHashProcessedHeight(string calldata hash) external view returns (int64);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`hash`|`string`|The Bitcoin transaction hash|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`int64`|The initial block height|


### isBtcTxHashAlreadyProcessed

Checks if a Bitcoin transaction hash has already been processed


```solidity
function isBtcTxHashAlreadyProcessed(string calldata hash) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`hash`|`string`|The Bitcoin transaction hash to check|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if the transaction has already been processed|


### getFederationAddress

Gets the federation address


```solidity
function getFederationAddress() external view returns (string memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`string`|The federation address|


### registerBtcTransaction

Registers a Bitcoin transaction


```solidity
function registerBtcTransaction(bytes calldata atx, int256 height, bytes calldata pmt) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`atx`|`bytes`|The serialized Bitcoin transaction|
|`height`|`int256`|The block height where the transaction was included|
|`pmt`|`bytes`|The partial merkle tree proof|


### addSignature

Adds a signature for a transaction


```solidity
function addSignature(bytes calldata pubkey, bytes[] calldata signatures, bytes calldata txHash) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`pubkey`|`bytes`|The public key of the signer|
|`signatures`|`bytes[]`|Array of signatures|
|`txHash`|`bytes`|The transaction hash|


### receiveHeaders

Receives multiple block headers


```solidity
function receiveHeaders(bytes[] calldata blocks) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`blocks`|`bytes[]`|Array of serialized block headers|


### receiveHeader

Receives a single block header


```solidity
function receiveHeader(bytes calldata ablock) external returns (int256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`ablock`|`bytes`|The serialized block header|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`int256`|The result code of the operation|


### getFederationSize

Gets the size of the federation


```solidity
function getFederationSize() external view returns (int256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`int256`|The number of federators in the federation|


### getFederationThreshold

Gets the threshold required for federation operations


```solidity
function getFederationThreshold() external view returns (int256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`int256`|The threshold number of federators required|


### getFederatorPublicKey

Gets the public key of a federator by index


```solidity
function getFederatorPublicKey(int256 index) external view returns (bytes memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`index`|`int256`|The index of the federator|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes`|The public key of the federator|


### getFederatorPublicKeyOfType

Gets the public key of a specific type for a federator


```solidity
function getFederatorPublicKeyOfType(int256 index, string calldata atype) external returns (bytes memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`index`|`int256`|The index of the federator|
|`atype`|`string`|The type of public key to retrieve|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes`|The public key of the specified type|


### getFederationCreationTime

Gets the creation time of the federation


```solidity
function getFederationCreationTime() external view returns (int256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`int256`|The timestamp when the federation was created|


### getFederationCreationBlockNumber

Gets the creation block number of the federation


```solidity
function getFederationCreationBlockNumber() external view returns (int256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`int256`|The block number when the federation was created|


### getRetiringFederationAddress

Gets the address of the retiring federation


```solidity
function getRetiringFederationAddress() external view returns (string memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`string`|The retiring federation address|


### getRetiringFederationSize

Gets the size of the retiring federation


```solidity
function getRetiringFederationSize() external view returns (int256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`int256`|The number of federators in the retiring federation|


### getRetiringFederationThreshold

Gets the threshold required for retiring federation operations


```solidity
function getRetiringFederationThreshold() external view returns (int256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`int256`|The threshold number of federators required for retiring federation|


### getRetiringFederatorPublicKey

Gets the public key of a retiring federator by index


```solidity
function getRetiringFederatorPublicKey(int256 index) external view returns (bytes memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`index`|`int256`|The index of the retiring federator|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes`|The public key of the retiring federator|


### getRetiringFederatorPublicKeyOfType

Gets the public key of a specific type for a retiring federator


```solidity
function getRetiringFederatorPublicKeyOfType(int256 index, string calldata atype)
    external
    view
    returns (bytes memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`index`|`int256`|The index of the retiring federator|
|`atype`|`string`|The type of public key to retrieve|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes`|The public key of the specified type for the retiring federator|


### getRetiringFederationCreationTime

Gets the creation time of the retiring federation


```solidity
function getRetiringFederationCreationTime() external view returns (int256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`int256`|The timestamp when the retiring federation was created|


### getRetiringFederationCreationBlockNumber

Gets the creation block number of the retiring federation


```solidity
function getRetiringFederationCreationBlockNumber() external view returns (int256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`int256`|The block number when the retiring federation was created|


### createFederation

Creates a new federation


```solidity
function createFederation() external returns (int256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`int256`|The result code of the operation|


### addFederatorPublicKey

Adds a federator public key


```solidity
function addFederatorPublicKey(bytes calldata key) external returns (int256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`key`|`bytes`|The public key to add|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`int256`|The result code of the operation|


### addFederatorPublicKeyMultikey

Adds a federator public key with multiple key types


```solidity
function addFederatorPublicKeyMultikey(bytes calldata btcKey, bytes calldata rskKey, bytes calldata mstKey)
    external
    returns (int256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`btcKey`|`bytes`|The Bitcoin public key|
|`rskKey`|`bytes`|The RSK public key|
|`mstKey`|`bytes`|The MST public key|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`int256`|The result code of the operation|


### commitFederation

Commits a federation with a specific hash


```solidity
function commitFederation(bytes calldata hash) external returns (int256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`hash`|`bytes`|The hash to commit|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`int256`|The result code of the operation|


### rollbackFederation

Rolls back the federation


```solidity
function rollbackFederation() external returns (int256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`int256`|The result code of the operation|


### getPendingFederationHash

Gets the hash of the pending federation


```solidity
function getPendingFederationHash() external view returns (bytes memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes`|The hash of the pending federation|


### getPendingFederationSize

Gets the size of the pending federation


```solidity
function getPendingFederationSize() external view returns (int256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`int256`|The number of federators in the pending federation|


### getPendingFederatorPublicKey

Gets the public key of a pending federator by index


```solidity
function getPendingFederatorPublicKey(int256 index) external view returns (bytes memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`index`|`int256`|The index of the pending federator|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes`|The public key of the pending federator|


### getPendingFederatorPublicKeyOfType

Gets the public key of a specific type for a pending federator


```solidity
function getPendingFederatorPublicKeyOfType(int256 index, string calldata atype) external view returns (bytes memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`index`|`int256`|The index of the pending federator|
|`atype`|`string`|The type of public key to retrieve|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes`|The public key of the specified type for the pending federator|


### getLockWhitelistSize

Gets the size of the lock whitelist


```solidity
function getLockWhitelistSize() external view returns (int256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`int256`|The number of addresses in the lock whitelist|


### getLockWhitelistAddress

Gets a lock whitelist address by index


```solidity
function getLockWhitelistAddress(int256 index) external view returns (string memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`index`|`int256`|The index of the whitelist entry|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`string`|The whitelisted address|


### getLockWhitelistEntryByAddress

Gets a lock whitelist entry by address


```solidity
function getLockWhitelistEntryByAddress(string calldata aaddress) external view returns (int256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`aaddress`|`string`|The address to look up|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`int256`|The index of the whitelist entry|


### addLockWhitelistAddress

Adds an address to the lock whitelist


```solidity
function addLockWhitelistAddress(string calldata aaddress, int256 maxTransferValue) external returns (int256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`aaddress`|`string`|The address to add|
|`maxTransferValue`|`int256`|The maximum transfer value allowed|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`int256`|The result code of the operation|


### addOneOffLockWhitelistAddress

Adds a one-off address to the lock whitelist


```solidity
function addOneOffLockWhitelistAddress(string calldata aaddress, int256 maxTransferValue) external returns (int256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`aaddress`|`string`|The address to add|
|`maxTransferValue`|`int256`|The maximum transfer value allowed|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`int256`|The result code of the operation|


### addUnlimitedLockWhitelistAddress

Adds an address with unlimited transfer value to the lock whitelist


```solidity
function addUnlimitedLockWhitelistAddress(string calldata aaddress) external returns (int256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`aaddress`|`string`|The address to add|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`int256`|The result code of the operation|


### removeLockWhitelistAddress

Removes an address from the lock whitelist


```solidity
function removeLockWhitelistAddress(string calldata aaddress) external returns (int256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`aaddress`|`string`|The address to remove|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`int256`|The result code of the operation|


### setLockWhitelistDisableBlockDelay

Sets the block delay for disabling the lock whitelist


```solidity
function setLockWhitelistDisableBlockDelay(int256 disableDelay) external returns (int256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`disableDelay`|`int256`|The delay in blocks|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`int256`|The result code of the operation|


### getFeePerKb

Gets the fee per kilobyte for transactions


```solidity
function getFeePerKb() external view returns (int256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`int256`|The fee per kilobyte in satoshis|


### voteFeePerKbChange

Votes for a change in the fee per kilobyte


```solidity
function voteFeePerKbChange(int256 feePerKb) external returns (int256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`feePerKb`|`int256`|The new fee per kilobyte to vote for|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`int256`|The result code of the operation|


### updateCollections

Updates collections


```solidity
function updateCollections() external;
```

### getMinimumLockTxValue

Gets the minimum lock transaction value


```solidity
function getMinimumLockTxValue() external view returns (int256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`int256`|The minimum value required for lock transactions|


### getBtcTransactionConfirmations

Gets the number of confirmations for a Bitcoin transaction


```solidity
function getBtcTransactionConfirmations(
    bytes32 txHash,
    bytes32 blockHash,
    uint256 merkleBranchPath,
    bytes32[] calldata merkleBranchHashes
) external view returns (int256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`txHash`|`bytes32`|The Bitcoin transaction hash|
|`blockHash`|`bytes32`|The block hash containing the transaction|
|`merkleBranchPath`|`uint256`|The merkle branch path|
|`merkleBranchHashes`|`bytes32[]`|Array of merkle branch hashes|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`int256`|The number of confirmations or error code|


### getLockingCap

Gets the current locking cap


```solidity
function getLockingCap() external view returns (int256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`int256`|The maximum amount that can be locked|


### increaseLockingCap

Increases the locking cap


```solidity
function increaseLockingCap(int256 newLockingCap) external returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newLockingCap`|`int256`|The new locking cap value|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if the operation was successful|


### registerBtcCoinbaseTransaction

Registers a Bitcoin coinbase transaction


```solidity
function registerBtcCoinbaseTransaction(
    bytes calldata btcTxSerialized,
    bytes32 blockHash,
    bytes calldata pmtSerialized,
    bytes32 witnessMerkleRoot,
    bytes32 witnessReservedValue
) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`btcTxSerialized`|`bytes`|The serialized Bitcoin transaction|
|`blockHash`|`bytes32`|The block hash containing the transaction|
|`pmtSerialized`|`bytes`|The serialized partial merkle tree|
|`witnessMerkleRoot`|`bytes32`|The witness merkle root|
|`witnessReservedValue`|`bytes32`|The witness reserved value|


### hasBtcBlockCoinbaseTransactionInformation

Checks if a Bitcoin block has coinbase transaction information


```solidity
function hasBtcBlockCoinbaseTransactionInformation(bytes32 blockHash) external returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`blockHash`|`bytes32`|The block hash to check|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if the block has coinbase transaction information|


### registerFastBridgeBtcTransaction

Registers a fast bridge Bitcoin transaction


```solidity
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
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`btcTxSerialized`|`bytes`|The serialized Bitcoin transaction|
|`height`|`uint256`|The block height|
|`pmtSerialized`|`bytes`|The serialized partial merkle tree|
|`derivationArgumentsHash`|`bytes32`|The hash of derivation arguments|
|`userRefundBtcAddress`|`bytes`|The user's refund Bitcoin address|
|`liquidityBridgeContractAddress`|`address payable`|The liquidity bridge contract address|
|`liquidityProviderBtcAddress`|`bytes`|The liquidity provider's Bitcoin address|
|`shouldTransferToContract`|`bool`|Whether to transfer to the contract|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`int256`|The result code of the operation|


### getActiveFederationCreationBlockHeight

Gets the active federation creation block height


```solidity
function getActiveFederationCreationBlockHeight() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The block height when the active federation was created|


### getActivePowpegRedeemScript

Gets the active Powpeg redeem script


```solidity
function getActivePowpegRedeemScript() external view returns (bytes memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes`|The active Powpeg redeem script|


### getBtcBlockchainBestBlockHeader

Gets the best block header of the Bitcoin blockchain


```solidity
function getBtcBlockchainBestBlockHeader() external view returns (bytes memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes`|The serialized best block header|


### getBtcBlockchainBlockHeaderByHash

Gets a Bitcoin blockchain block header by hash


```solidity
function getBtcBlockchainBlockHeaderByHash(bytes32 btcBlockHash) external view returns (bytes memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`btcBlockHash`|`bytes32`|The Bitcoin block hash|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes`|The serialized block header|


### getBtcBlockchainBlockHeaderByHeight

Gets a Bitcoin blockchain block header by height


```solidity
function getBtcBlockchainBlockHeaderByHeight(uint256 btcBlockHeight) external view returns (bytes memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`btcBlockHeight`|`uint256`|The Bitcoin block height|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes`|The serialized block header|


### getBtcBlockchainParentBlockHeaderByHash

Gets the parent block header of a Bitcoin block by hash


```solidity
function getBtcBlockchainParentBlockHeaderByHash(bytes32 btcBlockHash) external view returns (bytes memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`btcBlockHash`|`bytes32`|The Bitcoin block hash|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes`|The serialized parent block header|


### getUnionBridgeContractAddress

Gets the Union Bridge contract address

*This method is new in RSKIP-502*

*This method will be only enabled for testnet and regtest environments. It will be disabled on mainnet.*


```solidity
function getUnionBridgeContractAddress() external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The Union Bridge contract address|


### setUnionBridgeContractAddressForTestnet

Sets the Union Bridge contract address for testnet

This method will allow authorized accounts to set the Union Bridge contract address for testnet.

*This method is new in RSKIP-502*

*This method will be only enabled for testnet and regtest environments. It will be disabled on mainnet to prevent unauthorized updates.*


```solidity
function setUnionBridgeContractAddressForTestnet(address unionBridgeContractAddress) external returns (int256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`unionBridgeContractAddress`|`address`|The Union Bridge contract address|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`int256`|The result code of the operation (0 is success, otherwise error code)|


### getUnionBridgeLockingCap

Gets the Union Bridge locking cap

*This method is new in RSKIP-502*


```solidity
function getUnionBridgeLockingCap() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The Union Bridge locking cap|


### increaseUnionBridgeLockingCap

Increases the Union Bridge locking cap

This method will allow authorized accounts to adjust the locking cap.

*This method is new in RSKIP-502*


```solidity
function increaseUnionBridgeLockingCap(uint256 newCap) external returns (int256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newCap`|`uint256`|The new locking cap value|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`int256`|The result code of the operation (0 is success, otherwise error code)|


### requestUnionBridgeRbtc

Requests minting of RBTC to the Union Bridge contract address

The max amount of RBTC to mint is determined by the Union Bridge locking cap

*This method is new in RSKIP-502*


```solidity
function requestUnionBridgeRbtc(uint256 amountInWeis) external returns (int256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amountInWeis`|`uint256`|The amount in weis to request|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`int256`|The result code of the operation (0 is success, otherwise error code)|


### releaseUnionBridgeRbtc

The Union Bridge contract will have the capability to send funds back to the PowPeg.

When this happens, the tracking entry for the amount transferred will need to be updated to reflect the returned RBTC

*This method is new in RSKIP-502*


```solidity
function releaseUnionBridgeRbtc() external payable returns (int256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`int256`|The result code of the operation (0 is success, otherwise error code)|


### getBaseEvent

Gets the base event


```solidity
function getBaseEvent() external view returns (bytes memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes`|The current base event, if no value is set, then it should return an empty array of bytes.|


### setBaseEvent

Sets the base event, it will override the previous value if it exists.

*This function will revert if:*

*- the caller is not the Union Bridge contract address*

*- the baseEvent array is greater than 128 bytes*


```solidity
function setBaseEvent(bytes memory baseEvent) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`baseEvent`|`bytes`|The new base event (must be less than 128 bytes)|


### clearBaseEvent

Clears the base event

*It stores an empty byte array under the baseEvent storage key of the Bridge, overriding whatever value was previously there.*

*This function will revert if  the caller is not the Union Bridge contract address*


```solidity
function clearBaseEvent() external;
```

### getSuperEvent

Gets the super event


```solidity
function getSuperEvent() external view returns (bytes memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes`|The current super event, if no value is set, then it should return an empty array of bytes.|


### setSuperEvent

Sets the super event, it will override the previous value if it exists.

*This function will revert if:*

*- the caller is not the Union Bridge contract address*

*- the superEvent array is greater than 128 bytes*


```solidity
function setSuperEvent(bytes memory superEvent) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`superEvent`|`bytes`|The new super event (must be less than 128 bytes)|


### clearSuperEvent

Clears the super event

*It stores an empty byte array under the superEvent storage key of the Bridge, overriding whatever value was previously there.*

*This function will revert if the caller is not the Union Bridge contract address*


```solidity
function clearSuperEvent() external;
```

