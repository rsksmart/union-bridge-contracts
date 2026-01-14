# PegoutManager
[Git Source](https://github.com/temp-rsk/bitvmx-union-bridge-contracts/blob/0c819fa3fad6abf73f5f2a830cc21b001080582f/src/PegoutManager.sol)

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
    address payable _bridgeAddress,
    ICommitteeRegistry _committeeRegistry,
    IBitcoinManager _bitcoinManager,
    PegoutManagerSettings memory _settings,
    IRbtcBridge _rbtcBridge
) public virtual initializer;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_initialOwner`|`address`|The initial owner of the contract|
|`_bridgeAddress`|`address payable`|The address of the pow-peg bridge contract|
|`_committeeRegistry`|`ICommitteeRegistry`|The committee registry contract address|
|`_bitcoinManager`|`IBitcoinManager`|The Bitcoin manager contract address|
|`_settings`|`PegoutManagerSettings`|The peg manager settings including timeouts|
|`_rbtcBridge`|`IRbtcBridge`|The RbtcBridge contract for burning RBTC|


### getPegoutTempInfo

Gets the temporary peg-out information for a given accept peg-in transaction id


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
|`<none>`|`PegoutTempInfo`|The temporary peg-out information|


### _validatePegoutRequest


```solidity
function _validatePegoutRequest(bytes calldata _userPubKey, uint256 amountInWei) internal pure;
```

### tryPegout

Initiates a peg-out operation by locking a slot and preparing the peg-out transaction

*This function LOCKS a slot in the appropriate stream and prepares the peg-out transaction*

*The user must send the exact amount of RBTC they want to peg-out*

*Emits the PegoutRequested event*

*Only callable when contract is unpaused*


```solidity
function tryPegout(bytes calldata _userPubKey) external payable nonReentrant whenNotPaused;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_userPubKey`|`bytes`|The user's compressed public key for the Bitcoin output|


### registerUserTake

Register a peg-out transaction from Bitcoin

*This function validates the peg-out transaction and marks the slot as COMPLETED*

*The transaction must spend the accept peg-in output and pay to the user's address*

*Emits the PegoutRegistered event*

*Only callable when contract is unpaused*


```solidity
function registerUserTake(BtcTxSPVProof calldata _pegoutTxSPVProof) external nonReentrant whenNotPaused;
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

*Each case has its own timeout and before triggering the operator take (after a User Take expiration)*

*signatures should be checked to see if the User Take was already signed*

*Partial signatures are used to skip those operators that have not signed the User Take*

*Emits OperatorTakeTriggered event upon successful triggering*

*Only callable when contract is unpaused*


```solidity
function triggerOperatorTake(bytes32 _pegoutTxid) external nonReentrant whenNotPaused;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_pegoutTxid`|`bytes32`|The transaction id of the peg-out request|


### registerAdvanceFunds


```solidity
function registerAdvanceFunds(bytes32 acceptPeginTxid, BtcTxSPVProof calldata _advanceFunds)
    external
    nonReentrant
    whenNotPaused;
```

### _verifyAdvanceFundsTx


```solidity
function _verifyAdvanceFundsTx(
    BtcTxSPVProof calldata _advanceFunds,
    PegoutTempInfo memory _pegoutInfo,
    uint64 _streamId
) internal view returns (bytes32 txid, int256 confirmations);
```

### _validateOperatorTakeAddress


```solidity
function _validateOperatorTakeAddress(bytes32 _acceptPeginTxid) internal view returns (PegoutTempInfo storage);
```

### registerReimbursementKickoff


```solidity
function registerReimbursementKickoff(bytes32 acceptPeginTxid, BtcTxSPVProof calldata _kickoffSPV)
    external
    nonReentrant
    whenNotPaused;
```

### registerOperatorTake

Deposits an operator take proof for a peg-out transaction

*Validates the SPV proof and marks the slot as paid when operator takes over*

*Only callable when the peg status is OPERATOR_TAKE*

*Emits PegoutRegistered event upon successful deposit*

*Only callable when contract is unpaused*


```solidity
function registerOperatorTake(BtcTxSPVProof calldata _pegoutTxSPVProof) external nonReentrant whenNotPaused;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_pegoutTxSPVProof`|`BtcTxSPVProof`|The BTC SPV proof of the operator take peg-out transaction|


### setUserTakeTimeout

Sets the timeout duration for user take operations

*Only callable by the contract owner*

*Emits UserTakeTimeoutUpdated event upon successful update*


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

*Emits OperatorTakeTimeoutUpdated event upon successful update*


```solidity
function setOperatorTakeTimeout(uint256 _timeout) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_timeout`|`uint256`|The new timeout duration in seconds|


### _closePacketIfLastSlot


```solidity
function _closePacketIfLastSlot(StreamPosition memory streamInfo) internal;
```

### _preparePegoutPrevoutDatas


```solidity
function _preparePegoutPrevoutDatas(Slot memory _slot) internal pure returns (PrevoutData[] memory);
```

