# IPegoutManager
[Git Source](https://github.com/rsksmart/union-bridge-contracts/blob/cf5421e1f47ca597147a56a1404f8189f6c70b20/src/interfaces/IPegoutManager.sol)

Interface for managing peg-out operations


## Functions
### getPegoutStartInfo

Gets start information stored during peg-out creation


```solidity
function getPegoutStartInfo(bytes32 _acceptPeginTxid) external view returns (PegoutStartInfo memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_acceptPeginTxid`|`bytes32`|The accept peg-in transaction id|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`PegoutStartInfo`|The start info (userPubKey, createdAt)|


### tryPegout

Initiates a peg-out operation by locking a slot and preparing the peg-out transaction

Reverts if a pegout is already in progress for the same stream

*This function LOCKS a slot in the appropriate stream and prepares the peg-out transaction*

*Requires payment in RBTC and will revert if no filled slot is available*

*The user must send the exact amount of RBTC they want to peg-out*

*Emits PegoutRequested event upon successful initiation*

*Only callable when contract is unpaused*


```solidity
function tryPegout(bytes calldata _userPubKey) external payable;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_userPubKey`|`bytes`|The user's compressed public key that will receive the Bitcoin funds|


### registerUserTake

Registers the Bitcoin peg-out transaction to the user account

*This function validates the peg-out transaction and marks the slot as COMPLETED*

*The transaction must spend the accept peg-in output and pay to the user's address*

*Emits the PegoutRegistered event*

*Only callable when contract is unpaused*


```solidity
function registerUserTake(BtcTxSPVProof calldata _pegoutTxSPVProof) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_pegoutTxSPVProof`|`BtcTxSPVProof`|The BTC SPV proof of the peg-out transaction|


### getPegoutQueueLength

Get queue size for enqueued peg-out requests for a specific stream


```solidity
function getPegoutQueueLength(uint64 _streamId) external view returns (uint64);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_streamId`|`uint64`|The stream identifier|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint64`|The number of enqueued peg-out requests for the specified stream|


### enqueuePegout

Enqueues a peg-out request for a specific stream

*This function allows users to enqueue their peg-out requests where there is a pegout in process*


```solidity
function enqueuePegout(bytes memory _userPubKey) external payable;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_userPubKey`|`bytes`|The user's compressed public key that will receive the Bitcoin funds|


### dequeuePegout

Dequeues a peg-out request for processing for a specific stream

*Should be called from the user that enqueued a pegout*


```solidity
function dequeuePegout(uint64 _streamId) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_streamId`|`uint64`|The stream identifier|


### tryProcessEnqueuedPegout

Tries to process an enqueued peg-out request for a specific stream


```solidity
function tryProcessEnqueuedPegout(uint64 _streamId) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_streamId`|`uint64`|The stream identifier|


## Events
### PegoutRequested
Event emitted when a peg-out is successfully requested


```solidity
event PegoutRequested(
    bytes userPubKey,
    uint256 indexed committeeId,
    BitcoinSignatureData pegoutSignatureData,
    uint64 streamId,
    uint64 packetNumber,
    uint64 slotId,
    uint64 amount
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`userPubKey`|`bytes`|The user's public key that will receive the Bitcoin funds|
|`committeeId`|`uint256`|The ID of the committee responsible for this peg-out|
|`pegoutSignatureData`|`BitcoinSignatureData`|The signature data for committee signing|
|`streamId`|`uint64`|The stream ID where the funds originated|
|`packetNumber`|`uint64`|The packet number within the stream|
|`slotId`|`uint64`|The slot ID within the packet|
|`amount`|`uint64`|The amount being peg-out in satoshis|

### PegoutRegistered
Event emitted when a peg-out is successfully registered


```solidity
event PegoutRegistered(
    bytes32 indexed blockHash,
    bytes32 indexed txid,
    bytes32 indexed acceptPeginTxid,
    uint128 committeeId,
    StreamPosition streamInfo
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`blockHash`|`bytes32`|The Bitcoin block hash containing the peg-out transaction|
|`txid`|`bytes32`|The hash of the peg-out transaction|
|`acceptPeginTxid`|`bytes32`|The txid of the original accept peg-in transaction|
|`committeeId`|`uint128`|The ID of the committee responsible for this peg-out|
|`streamInfo`|`StreamPosition`|The stream position information related to this peg-out|

### PegoutEnqueued
Event emitted when a peg-out request is enqueued


```solidity
event PegoutEnqueued(uint64 indexed streamId, bytes userPubKey, address userAddress);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`streamId`|`uint64`|The stream identifier for which the peg-out request is enqueued|
|`userPubKey`|`bytes`|The user's public key that will receive the Bitcoin funds|
|`userAddress`|`address`|The user's RSK address in case a refund is needed|

### PegoutDequeued
Event emitted when a peg-out request is dequeued for processing


```solidity
event PegoutDequeued(uint64 indexed streamId, bytes userPubKey, address userAddress);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`streamId`|`uint64`|The stream identifier for which the peg-out request is dequeued|
|`userPubKey`|`bytes`|The user's public key that will receive the Bitcoin funds|
|`userAddress`|`address`|The user's RSK address in case a refund is needed|

## Errors
### PegoutRequestAmountExceedsUint64Limit
Thrown when peg-out request amount exceeds uint64 limit


```solidity
error PegoutRequestAmountExceedsUint64Limit(uint256 amount);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|The amount that exceeded the limit|

### IncorrectInputsNumber
Thrown when the number of inputs doesn't match the expected count


```solidity
error IncorrectInputsNumber(uint256 actual, uint256 expected);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`actual`|`uint256`|The actual number of inputs|
|`expected`|`uint256`|The expected number of inputs|

### IncorrectOutputsNumber
Thrown when the number of outputs doesn't match the expected count


```solidity
error IncorrectOutputsNumber(uint256 actual, uint256 expected);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`actual`|`uint256`|The actual number of outputs|
|`expected`|`uint256`|The expected number of outputs|

### InvalidCompressedPubKey
Thrown when the provided public key is not in valid compressed format


```solidity
error InvalidCompressedPubKey(bytes userPubKey);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`userPubKey`|`bytes`|The invalid public key that was provided|

### InvalidLocktime
Thrown when the transaction locktime doesn't match the expected value


```solidity
error InvalidLocktime(uint256 actual, uint256 expected);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`actual`|`uint256`|The actual locktime value|
|`expected`|`uint256`|The expected locktime value|

### InvalidBtcTxVersion
Thrown when the Bitcoin transaction version doesn't match the expected value


```solidity
error InvalidBtcTxVersion(uint256 actual, uint256 expected);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`actual`|`uint256`|The actual version value|
|`expected`|`uint256`|The expected version value|

### InvalidSlotState
Thrown when the slot state doesn't match the expected state


```solidity
error InvalidSlotState(SlotState actual, SlotState expected);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`actual`|`SlotState`|The actual slot state|
|`expected`|`SlotState`|The expected slot state|

### IncorrectVout
Thrown when the output index (vout) doesn't match the expected value


```solidity
error IncorrectVout(uint32 actual, uint32 expected);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`actual`|`uint32`|The actual vout value|
|`expected`|`uint32`|The expected vout value|

### IncorrectOutputScript
Thrown when the output script doesn't match the expected format


```solidity
error IncorrectOutputScript(bytes actual, bytes expected);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`actual`|`bytes`|The actual script bytes|
|`expected`|`bytes`|The expected script bytes|

### PegoutQueueFull
Thrown when the pegout queue has reached its maximum size


```solidity
error PegoutQueueFull(uint64 streamId);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`streamId`|`uint64`|The stream identifier|

### NoEnqueuedPegout
Thrown when there are no enqueued peg-outs to process


```solidity
error NoEnqueuedPegout(uint64 streamId);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`streamId`|`uint64`|The stream identifier for which there are no enqueued peg-outs to process|

### NoFreeFilledSlot
Thrown when there are no free filled slots available for peg-out in the specified stream


```solidity
error NoFreeFilledSlot(uint64 streamId, uint64 queueLength, uint64 remainingFilledSlots);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`streamId`|`uint64`|The stream identifier|
|`queueLength`|`uint64`|The current length of the peg-out queue for the stream|
|`remainingFilledSlots`|`uint64`|The number of remaining filled slots available for peg-out in the stream|

### PegoutNotFoundInQueue
Thrown when trying to process an enqueued peg-out but the peg-out data is not found in the queue


```solidity
error PegoutNotFoundInQueue(uint64 streamId, address userAddress);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`streamId`|`uint64`|The stream identifier for which the peg-out data was not found|
|`userAddress`|`address`|The user's RSK address associated with the peg-out request that was not found|

### FailedToSendRSK
Thrown when RSK transfer fails


```solidity
error FailedToSendRSK(address userAddress, uint256 amount);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`userAddress`|`address`|The user's address|
|`amount`|`uint256`|The amount that failed to transfer|

### EnqueuedPegoutsForStream
Thrown when trying to process a peg-out but there is already an enqueued peg-out for the same stream


```solidity
error EnqueuedPegoutsForStream(uint64 streamId, uint64 queueLength);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`streamId`|`uint64`|The stream identifier for which there is already an enqueued peg-out|
|`queueLength`|`uint64`|The current length of the peg-out queue for the stream|

### PegoutNotFoundForPegin
Thrown when a peg-out txid is not found for the given accept peg-in transaction id


```solidity
error PegoutNotFoundForPegin(bytes32 acceptPeginTxid);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`acceptPeginTxid`|`bytes32`|The accept peg-in transaction that doesn't have a pegout txid associated.|

