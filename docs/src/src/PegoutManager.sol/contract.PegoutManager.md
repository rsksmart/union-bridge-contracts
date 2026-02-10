# PegoutManager
[Git Source](https://github.com/temp-rsk/bitvmx-union-bridge-contracts/blob/6a9ea8ca3ca82c82894d3db0e338e4bf6bb46de8/src/PegoutManager.sol)

**Inherits:**
[IPegoutManager](/src/interfaces/IPegoutManager.sol/interface.IPegoutManager.md), [PegManagerBase](/src/PegManagerBase.sol/abstract.PegManagerBase.md)

Manages peg-out operations from Rootstock to Bitcoin


## State Variables
### userTakeTimeout
Timeout in seconds for user take operations


```solidity
uint256 public userTakeTimeout;
```


### operatorTakeTimeout
Timeout in seconds for operator take operations


```solidity
uint256 public operatorTakeTimeout;
```


### sequenceNumber
The pegout ID sequence number incremented for each new triggerOperatorTake


```solidity
uint256 public sequenceNumber;
```


### pegoutTempInfo

```solidity
mapping(bytes32 acceptPeginTxid => PegoutTempInfo tempInfo) internal pegoutTempInfo;
```


### pegoutToPeginTxid

```solidity
mapping(bytes32 pegoutTxid => bytes32 acceptPeginTxid) internal pegoutToPeginTxid;
```


### pegoutTxids

```solidity
mapping(bytes32 key => bytes32 pegoutTxid) internal pegoutTxids;
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
    ISignatureManager _signatureManager,
    PegoutManagerSettings memory _settings
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
|`_settings`|`PegoutManagerSettings`|The peg manager settings including timeouts|


### getPegoutTempInfo

Gets temporary information stored during peg-out processing


```solidity
function getPegoutTempInfo(bytes32 _acceptPeginTxid) external view returns (PegoutTempInfo memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_acceptPeginTxid`|`bytes32`|The accept peg-in transaction id|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`PegoutTempInfo`|The temporary information needed for peg-out processing|


### getAcceptPeginTxid

Gets the accept peg-in transaction id for a given peg-out transaction id


```solidity
function getAcceptPeginTxid(bytes32 _pegoutTxid) external view returns (bytes32);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_pegoutTxid`|`bytes32`|The peg-out transaction id|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|The accept peg-in transaction id|


### _validatePegoutRequest


```solidity
function _validatePegoutRequest(bytes memory _userPubKey, uint256 amountInWei) internal pure;
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


### getPegoutTxid

Gets the peg-out signature hash for a specific stream, packet, and slot


```solidity
function getPegoutTxid(uint64 streamId, uint64 packetNumber, uint64 slotId) external view returns (bytes32);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`streamId`|`uint64`|The stream identifier|
|`packetNumber`|`uint64`|The packet number within the stream|
|`slotId`|`uint64`|The slot identifier within the packet|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|The peg-out signature hash|


### _storePegoutAndInitSignatures


```solidity
function _storePegoutAndInitSignatures(bytes32 _pegoutTxid, uint64 _streamId, uint64 _packetNumber, uint64 _slotId)
    internal
    returns (uint128);
```

### triggerOperatorTake

Triggers the operator take process for a peg-out when not all committee members sign within timeout

*This function can be called after a User Take expiration or after an Operator Take expiration*


```solidity
function triggerOperatorTake(bytes32 _pegoutTxid) external nonReentrant whenNotPaused;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_pegoutTxid`|`bytes32`|The transaction id of the peg-out request|


### _generatePegoutId


```solidity
function _generatePegoutId(StreamPosition memory _streamInfo, bytes32 _operatorTakePubKey, uint256 _sequenceNumber)
    internal
    view
    returns (bytes32);
```

### registerAdvanceFunds

Registers the advance funds transaction submitted by the operator

*Validates the SPV proof and updated the peg-out status accordingly*


```solidity
function registerAdvanceFunds(bytes32 acceptPeginTxid, BtcTxSPVProof memory _advanceFunds)
    external
    nonReentrant
    whenNotPaused;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`acceptPeginTxid`|`bytes32`|The accept peg-in transaction id that it's being advanced|
|`_advanceFunds`|`BtcTxSPVProof`|The BTC SPV proof of the advance funds transaction|


### _verifyAdvanceFundsTx


```solidity
function _verifyAdvanceFundsTx(BtcTxSPVProof memory _advanceFunds, PegoutTempInfo memory _pegoutInfo, uint64 _streamId)
    internal
    view
    returns (bytes32 txid, int256 blockNumber);
```

### _validateOperatorTakeAddress


```solidity
function _validateOperatorTakeAddress(bytes32 _acceptPeginTxid) internal view returns (PegoutTempInfo storage);
```

### registerReimbursementKickoff

Registers the reimbursement kickoff transaction submitted by the operator

*Validates the SPV proof and updates the peg-out status accordingly*


```solidity
function registerReimbursementKickoff(bytes32 acceptPeginTxid, BtcTxSPVProof memory _kickoffSPV)
    external
    nonReentrant
    whenNotPaused;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`acceptPeginTxid`|`bytes32`|The accept peg-in transaction id that it's being reimbursed|
|`_kickoffSPV`|`BtcTxSPVProof`|The BTC SPV proof of the reimbursement kickoff transaction|


### registerOperatorTake

Deposits an operator take proof for a peg-out transaction

*Validates the SPV proof and marks the slot as paid when operator takes over*


```solidity
function registerOperatorTake(BtcTxSPVProof memory _pegoutTxSPVProof) external nonReentrant whenNotPaused;
```

### registerOperatorWon

Deposits an operator won proof for a peg-out transaction

*Validates the SPV proof and marks the slot as paid when operator takes over*

*Only callable when the peg status is OPERATOR_TAKE*

*Emits PegoutRegistered event upon successful deposit*

*Only callable when contract is unpaused*


```solidity
function registerOperatorWon(BtcTxSPVProof memory _pegoutTxSPVProof) external nonReentrant whenNotPaused;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_pegoutTxSPVProof`|`BtcTxSPVProof`|The BTC SPV proof of the operator won transaction|


### _completeSlot


```solidity
function _completeSlot(StreamPosition memory _streamInfo, bytes32 _acceptPeginTxid, bytes32 _txid) internal;
```

### _getOperatorTakeData


```solidity
function _getOperatorTakeData(bytes32 _acceptPeginTxid, address _opAddress)
    internal
    view
    returns (OperatorTakeData memory);
```

### setUserTakeTimeout

Sets the timeout duration for user take operations

*Only callable by the contract owner*


```solidity
function setUserTakeTimeout(uint256 _timeout) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_timeout`|`uint256`|The new timeout duration in seconds|


### setOperatorTakeTimeout

Sets the timeout duration for operator take operations

*Only callable by the contract owner*


```solidity
function setOperatorTakeTimeout(uint256 _timeout) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_timeout`|`uint256`|The new timeout duration in seconds|


### _preparePegoutPrevoutDatas


```solidity
function _preparePegoutPrevoutDatas(uint64 _streamId, uint64 _packetNumber, Slot memory _slot)
    internal
    view
    returns (PrevoutData[] memory);
```

