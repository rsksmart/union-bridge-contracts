# ProofValidator
[Git Source](https://github.com/temp-rsk/bitvmx-union-bridge-contracts/blob/71daf3bfeba3a077e1d33188a46c6e2cfea30519/src/ProofValidator.sol)

**Inherits:**
Initializable

Simple proof validator for proving Bitcoin transactions in RSK

*Provides functionality to verify Bitcoin transaction confirmations using the RSK Bridge*

*Uses the RSK Bridge precompiled contract to validate transaction proofs*


## State Variables
### bridge
The RSK Bridge contract used for Bitcoin transaction verification

*This contract provides access to Bitcoin transaction confirmation data*


```solidity
IBridge public bridge;
```


## Functions
### __ProofValidator_init

Initializes the ProofValidator contract

*Sets up the RSK Bridge address for Bitcoin transaction verification*

*Can only be called once during contract deployment*


```solidity
function __ProofValidator_init(address payable _bridgeAddress) internal initializer;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_bridgeAddress`|`address payable`|The address of the RSK Bridge contract|


### _verifyTxConfirmations

Verifies that a Bitcoin transaction exists in a block and has enough confirmations

*Uses RSK bridge precompiled contract to verify the transaction via ProofValidator*

*Will revert if:
- Block hash doesn't exist
- Block is not in best chain
- Block data is inconsistent
- Block is too old (> 1 month)
- Merkle proof is invalid
- Not enough confirmations*


```solidity
function _verifyTxConfirmations(
    uint256 _minConfirmations,
    bytes32 _txid,
    bytes32 _blockHash,
    uint256 _merkleBranchPath,
    bytes32[] memory _merkleBranchHashes
) internal view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_minConfirmations`|`uint256`|The minimum number of confirmations required for the transaction|
|`_txid`|`bytes32`|The hash of the Bitcoin transaction to verify|
|`_blockHash`|`bytes32`|The hash of the block containing the transaction|
|`_merkleBranchPath`|`uint256`|The path in the merkle tree to verify the transaction|
|`_merkleBranchHashes`|`bytes32[]`|The hashes needed to verify the merkle proof|


### _mintRbtc

Mints RBTC to the Union Bridge contract address

*Uses RSK bridge precompiled contract to mint the RBTC via requestUnionBridgeRbtc*

*following RSKIP502: https://github.com/rsksmart/RSKIPs/blob/master/IPs/RSKIP502.md*

*Will revert if:
- Unauthorized caller
- Exceeded locking cap
- Transfers disabled
- Unknown error*


```solidity
function _mintRbtc(address payable _to, uint256 _amount) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_to`|`address payable`|The address to transfer the RBTC to|
|`_amount`|`uint256`|The amount of RBTC to mint|


### _sendRbtc

Sends RBTC to the specified address using a low gas limit

*Limit is set to 100_000 to avoid DDoS attacks and stealing gas while allowing to perform some smart contract operations for DEFI.*

*Will revert if:
- Unable to send RBTC
- Exceeded gas limit*


```solidity
function _sendRbtc(address payable _to, uint256 _amount) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_to`|`address payable`|The address to send the RBTC to|
|`_amount`|`uint256`|The amount of RBTC to send|


### _releaseRbtc

Releases RBTC to the powpeg bridge following RSKIP502 https://github.com/rsksmart/RSKIPs/blob/master/IPs/RSKIP502.md

*Will revert if:
- Unauthorized caller
- Invalid Value: Amount to return exceeds the previously transferred amount
- Transfers disabled
- Unknown error*


```solidity
function _releaseRbtc(uint256 _amountToReturn) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_amountToReturn`|`uint256`|The amount of RBTC to release|


## Errors
### BridgeBtcInexistantBlockHash
Error thrown when the provided Bitcoin block hash doesn't exist


```solidity
error BridgeBtcInexistantBlockHash(bytes32 blockHash);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`blockHash`|`bytes32`|The non-existent block hash that was provided|

### BridgeBtcBlockNotInBestChain
Error thrown when the provided Bitcoin block is not in the best chain


```solidity
error BridgeBtcBlockNotInBestChain(bytes32 blockHash);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`blockHash`|`bytes32`|The block hash that is not in the best chain|

### BridgeBtcInconsistentBlock
Error thrown when the provided Bitcoin block data is inconsistent


```solidity
error BridgeBtcInconsistentBlock(bytes32 blockHash);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`blockHash`|`bytes32`|The block hash with inconsistent data|

### BridgeBtcBlockTooOld
Error thrown when the provided Bitcoin block is too old (> 1 month)


```solidity
error BridgeBtcBlockTooOld(int256 maxDepth);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`maxDepth`|`int256`|The maximum allowed depth for block retrieval|

### BridgeBtcTxInvalidMerkleBranch
Error thrown when the merkle proof for a Bitcoin transaction is invalid


```solidity
error BridgeBtcTxInvalidMerkleBranch(bytes32 txid, uint256 merkleBranchPath, bytes32[] merkleBranchHashes);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`txid`|`bytes32`|The transaction id that failed merkle proof verification|
|`merkleBranchPath`|`uint256`|The merkle branch path that was used|
|`merkleBranchHashes`|`bytes32[]`|The merkle branch hashes that were provided|

### BridgeBtcUnknownError
Error thrown when the RSK Bridge returns an unknown error code


```solidity
error BridgeBtcUnknownError(int256 errorCode);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`errorCode`|`int256`|The unknown error code returned by the bridge|

### NotEnoughConfirmations
Error thrown when a transaction doesn't have enough confirmations


```solidity
error NotEnoughConfirmations(int256 actual, uint256 expected);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`actual`|`int256`|The actual number of confirmations the transaction has|
|`expected`|`uint256`|The minimum number of confirmations required|

### FailedToSendRBTC
Error thrown when unable to transfer RBTC


```solidity
error FailedToSendRBTC(address to, uint256 amount);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`to`|`address`|The address to transfer the RBTC to|
|`amount`|`uint256`|The amount of RBTC to transfer|

### BridgeAddressZero
Error thrown when the bridge address is set to zero


```solidity
error BridgeAddressZero();
```

### BridgeUnauthorizedCaller
Error thrown when an unauthorized caller attempts to access bridge functionality


```solidity
error BridgeUnauthorizedCaller();
```

### BridgeTransfersDisabled
Error thrown when RBTC transfers from the PowPeg to the Union Bridge are currently disabled


```solidity
error BridgeTransfersDisabled();
```

### BridgeExceededLockingCap
Error thrown when the locking cap is exceeded


```solidity
error BridgeExceededLockingCap(uint256 amount);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|The amount that would exceed the locking cap|

### BridgeReleaseInvalidValue
Error thrown when the amount being returned exceeds the previously transferred amount.


```solidity
error BridgeReleaseInvalidValue(uint256 amount);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|The amount that would exceed previously transferred amount|

