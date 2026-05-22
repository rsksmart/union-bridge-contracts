# IRbtcBridge
[Git Source](https://github.com/rsksmart/union-bridge-contracts/blob/68c14faa89612dfba1b7e9abf29455625661476f/src/interfaces/IRbtcBridge.sol)

Interface for the RbtcBridge contract that acts as the single authorized intermediary
between the Union Bridge system and the RSK PowPeg Bridge for RBTC minting/burning operations

*This contract is required because RSKIP-502 only allows ONE contract address to be authorized
for minting and burning RBTC from the PowPeg bridge. Since PegManager is split into
PeginManager and PegoutManager, we need this intermediary to be the single authorized address.*


## Functions
### bridge

Gets the RSK pow-peg Bridge contract


```solidity
function bridge() external view returns (IBridge);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`IBridge`|The RSK PowPeg Bridge contract|


### mintRbtc

Mints RBTC from the PowPeg bridge and sends it to the specified address

*Only callable by the peginManager when contract is not paused*

*Requests RBTC from PowPeg bridge via requestUnionBridgeRbtc*

*Transfers RBTC to recipient with 100k gas limit*


```solidity
function mintRbtc(address payable _to, uint256 _amount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_to`|`address payable`|The address to receive the minted RBTC|
|`_amount`|`uint256`|The amount of RBTC to mint in wei|


### burnRbtc

Burns RBTC back to the PowPeg bridge

*Only callable by the pegoutManager when contract is not paused*

*The pegoutManager must send the RBTC amount via msg.value*

*Returns RBTC to PowPeg bridge via releaseUnionBridgeRbtc*


```solidity
function burnRbtc() external payable;
```

### getUnionBridgeLockingCap

Gets the locking cap of the Union Bridge for RBTC minting operations


```solidity
function getUnionBridgeLockingCap() external view returns (uint256 unionBridgeLockingCap);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`unionBridgeLockingCap`|`uint256`|The locking cap of the Union Bridge|


### getBestBlockHash

Gets the hash of the best block in the Bitcoin blockchain


```solidity
function getBestBlockHash() external view returns (bytes32 bestBlockHash);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`bestBlockHash`|`bytes32`|The hash of the best block in the Bitcoin blockchain|


### verifyTxConfirmations

Verifies that a Bitcoin transaction exists in a block and has enough confirmations

*Uses RSK bridge precompiled contract to verify the transaction*

*Will revert if:
- Block hash doesn't exist
- Block is not in best chain
- Block data is inconsistent
- Block is too old (> 1 month)
- Merkle proof is invalid
- Not enough confirmations*


```solidity
function verifyTxConfirmations(
    uint256 _minConfirmations,
    bytes32 _txid,
    bytes32 _blockHash,
    uint256 _merkleBranchPath,
    bytes32[] memory _merkleBranchHashes
) external view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_minConfirmations`|`uint256`|The minimum number of confirmations required for the transaction|
|`_txid`|`bytes32`|The hash of the Bitcoin transaction to verify|
|`_blockHash`|`bytes32`|The hash of the block containing the transaction|
|`_merkleBranchPath`|`uint256`|The path in the merkle tree to verify the transaction|
|`_merkleBranchHashes`|`bytes32[]`|The hashes needed to verify the merkle proof|


### getTxBlockNumberAndVerifyConfirmations

Verifies that a Bitcoin transaction exists in a block and has enough confirmations

*Uses RSK bridge precompiled contract to verify the transaction*

*Will revert if:
- Block hash doesn't exist
- Block is not in best chain
- Block data is inconsistent
- Block is too old (> 1 month)
- Merkle proof is invalid
- Not enough confirmations*


```solidity
function getTxBlockNumberAndVerifyConfirmations(
    uint256 _minConfirmations,
    bytes32 _txid,
    bytes32 _blockHash,
    uint256 _merkleBranchPath,
    bytes32[] memory _merkleBranchHashes
) external view returns (int256 blockNumber);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_minConfirmations`|`uint256`|The minimum number of confirmations required for the transaction|
|`_txid`|`bytes32`|The hash of the Bitcoin transaction to verify|
|`_blockHash`|`bytes32`|The hash of the block containing the transaction|
|`_merkleBranchPath`|`uint256`|The path in the merkle tree to verify the transaction|
|`_merkleBranchHashes`|`bytes32[]`|The hashes needed to verify the merkle proof|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`blockNumber`|`int256`|The block number of the transaction|


### setBaseEvent

Sets the base event

*This function will revert if:*

*- the _baseEvent parameter is empty error BaseEventEmpty*

*- the _baseEvent parameter is greater than 128 bytes error BaseEventTooLong*

*- there is another event already set with error BaseEventAlreadySet*


```solidity
function setBaseEvent(bytes memory _baseEvent) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_baseEvent`|`bytes`|The new base event (must be less than 128 bytes)|


## Events
### RbtcMinted
Emitted when RBTC is minted and sent to a user


```solidity
event RbtcMinted(address indexed to, uint256 amount);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`to`|`address`|The address that received the RBTC|
|`amount`|`uint256`|The amount of RBTC minted in wei|

### RbtcBurned
Emitted when RBTC is burned back to the PowPeg bridge


```solidity
event RbtcBurned(uint256 amount);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|The amount of RBTC burned in wei|

### BaseEventSet
Emitted when the base event is set


```solidity
event BaseEventSet(bytes baseEvent);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`baseEvent`|`bytes`|The new base event|

## Errors
### UnauthorizedCaller
Thrown when an unauthorized address attempts to call a restricted function


```solidity
error UnauthorizedCaller(address caller);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`caller`|`address`|The address that attempted the unauthorized call|

### FailedToSendRBTC
Thrown when RBTC transfer to recipient fails


```solidity
error FailedToSendRBTC(address to, uint256 amount);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`to`|`address`|The intended recipient address|
|`amount`|`uint256`|The amount that failed to transfer|

### BridgeUnauthorizedCaller
Thrown when the PowPeg bridge rejects the request due to unauthorized caller (error code -1)


```solidity
error BridgeUnauthorizedCaller();
```

### BridgeExceededLockingCap
Thrown when the requested amount exceeds the PowPeg bridge locking cap (error code -2)


```solidity
error BridgeExceededLockingCap(uint256 amount);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|The amount that exceeded the cap|

### BridgeTransfersDisabled
Thrown when RBTC transfers are currently disabled in the PowPeg bridge (error code -3)


```solidity
error BridgeTransfersDisabled();
```

### BridgeReleaseInvalidValue
Thrown when the burn amount exceeds the previously minted amount (error code -2)


```solidity
error BridgeReleaseInvalidValue(uint256 amount);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|The invalid burn amount|

### BridgeBtcUnknownError
Thrown when the PowPeg bridge returns an unknown error code


```solidity
error BridgeBtcUnknownError(int256 errorCode);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`errorCode`|`int256`|The error code returned by the bridge|

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

### BaseEventAlreadySet
Error thrown when the base event is already set


```solidity
error BaseEventAlreadySet();
```

### BaseEventTooLong
Error thrown when the base event is longer than 128 bytes


```solidity
error BaseEventTooLong();
```

### BaseEventEmpty
Error thrown when the base event is empty


```solidity
error BaseEventEmpty();
```

