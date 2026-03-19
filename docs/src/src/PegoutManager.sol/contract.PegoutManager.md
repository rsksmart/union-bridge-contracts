# PegoutManager
[Git Source](https://github.com/temp-rsk/bitvmx-union-bridge-contracts/blob/ee0115174aa9f16d975ad140f940d23fb1883b23/src/PegoutManager.sol)

**Inherits:**
[IPegoutManager](/src/interfaces/IPegoutManager.sol/interface.IPegoutManager.md), [PegManagerBase](/src/PegManagerBase.sol/abstract.PegManagerBase.md)

Manages peg-out operations from Rootstock to Bitcoin


## State Variables
### pegoutStartInfo

```solidity
mapping(bytes32 acceptPeginTxid => PegoutStartInfo startInfo) internal pegoutStartInfo;
```


### pegoutQueue

```solidity
mapping(uint64 streamId => PegoutRequest[]) internal pegoutQueue;
```


### currentPegoutQueuePointer

```solidity
mapping(uint64 streamId => uint64) internal currentPegoutQueuePointer;
```


## Functions
### initialize

Initializes the PegManager contract

*This function can only be called once during contract deployment*


```solidity
function initialize(
    address _initialOwner,
    address _accessManager,
    ICommitteeRegistry _committeeRegistry,
    IBitcoinManager _bitcoinManager,
    IRbtcBridge _rbtcBridge,
    IStreamManager _streamManager,
    ISignatureManager _signatureManager
) public virtual initializer;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_initialOwner`|`address`|The initial owner of the contract|
|`_accessManager`|`address`|The access manager contract address|
|`_committeeRegistry`|`ICommitteeRegistry`|The committee registry contract address|
|`_bitcoinManager`|`IBitcoinManager`|The Bitcoin manager contract address|
|`_rbtcBridge`|`IRbtcBridge`|The RbtcBridge contract for burning RBTC|
|`_streamManager`|`IStreamManager`|The stream manager contract address|
|`_signatureManager`|`ISignatureManager`|The signature manager contract address|


### getPegoutStartInfo

Gets start information stored during peg-out creation


```solidity
function getPegoutStartInfo(bytes32 _acceptPeginTxid) external view returns (PegoutStartInfo memory pegoutInfo);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_acceptPeginTxid`|`bytes32`|The accept peg-in transaction id|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`pegoutInfo`|`PegoutStartInfo`|The start info (userPubKey, createdAt)|


### _validatePegoutRequest


```solidity
function _validatePegoutRequest(bytes memory _userPubKey, uint256 _amountInWei)
    internal
    view
    returns (Stream memory stream, uint64 queueLength);
```

### enqueuePegout

Enqueues a peg-out request for a specific stream

*This function allows users to enqueue their peg-out requests where there is a pegout in process*


```solidity
function enqueuePegout(bytes memory _userPubKey) external payable nonReentrant whenNotPaused;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_userPubKey`|`bytes`|The user's compressed public key that will receive the Bitcoin funds|


### dequeuePegout

Dequeues a peg-out request for processing for a specific stream

*Should be called from the user that enqueued a pegout*


```solidity
function dequeuePegout(uint64 _streamId) external nonReentrant whenNotPaused;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_streamId`|`uint64`|The stream identifier|


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


### _getPegoutQueueLength


```solidity
function _getPegoutQueueLength(uint64 _streamId) internal view returns (uint64);
```

### _popPegoutQueue


```solidity
function _popPegoutQueue(uint64 _streamId) internal returns (PegoutRequest memory request);
```

### tryProcessEnqueuedPegout

Tries to process an enqueued peg-out request for a specific stream


```solidity
function tryProcessEnqueuedPegout(uint64 _streamId) external nonReentrant whenNotPaused;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_streamId`|`uint64`|The stream identifier|


### _processPegout


```solidity
function _processPegout(bytes memory _userPubKey, Stream memory _stream) internal;
```

### tryPegout

Initiates a peg-out operation by locking a slot and preparing the peg-out transaction

*This function LOCKS a slot in the appropriate stream and prepares the peg-out transaction*


```solidity
function tryPegout(bytes memory _userPubKey) external payable nonReentrant whenNotPaused;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_userPubKey`|`bytes`|The user's compressed public key that will receive the Bitcoin funds|


### registerUserTake

Registers the Bitcoin peg-out transaction to the user account

*This function validates the peg-out transaction and marks the slot as COMPLETED*


```solidity
function registerUserTake(BtcTxSPVProof memory _pegoutTxSPVProof) external nonReentrant whenNotPaused;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_pegoutTxSPVProof`|`BtcTxSPVProof`|The BTC SPV proof of the peg-out transaction|


### _storePegoutAndInitSignatures


```solidity
function _storePegoutAndInitSignatures(bytes32 _pegoutTxid, uint64 _streamId, uint64 _packetNumber, uint64 _slotId)
    internal
    returns (uint128);
```

### _preparePegoutPrevoutDatas


```solidity
function _preparePegoutPrevoutDatas(uint64 _streamId, uint64 _packetNumber, Slot memory _slot)
    internal
    view
    returns (PrevoutData[] memory);
```

