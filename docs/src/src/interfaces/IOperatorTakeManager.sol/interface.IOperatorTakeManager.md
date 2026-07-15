# IOperatorTakeManager
[Git Source](https://github.com/rsksmart/union-bridge-contracts/blob/6c85aeb17a23ee9d675a92f8655a551ecca7b4c9/src/interfaces/IOperatorTakeManager.sol)

Interface for operator take flow: advance funds, kickoff, operator take, operator won


## Functions
### registerAdvanceFunds

Registers the advance funds transaction submitted by the operator

*Validates the SPV proof and updates the peg-out status accordingly*


```solidity
function registerAdvanceFunds(bytes32 _acceptPeginTxid, BtcTxSPVProof calldata _advanceFunds) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_acceptPeginTxid`|`bytes32`|The accept peg-in transaction id that it's being advanced|
|`_advanceFunds`|`BtcTxSPVProof`|The BTC SPV proof of the advance funds transaction|


### registerReimbursementKickoff

Registers the reimbursement kickoff transaction submitted by the operator

*Validates the SPV proof and updates the peg-out status accordingly*


```solidity
function registerReimbursementKickoff(bytes32 _acceptPeginTxid, BtcTxSPVProof calldata _kickoffSPV) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_acceptPeginTxid`|`bytes32`|The accept peg-in transaction id that it's being reimbursed|
|`_kickoffSPV`|`BtcTxSPVProof`|The BTC SPV proof of the reimbursement kickoff transaction|


### registerCancelUserTake

Registers the cancel user take proof submitted by the operator

*Validates the SPV proof*


```solidity
function registerCancelUserTake(BtcTxSPVProof calldata _cancelUserTakeSPVProof) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_cancelUserTakeSPVProof`|`BtcTxSPVProof`|The BTC SPV proof of the cancel user take transaction|


### registerOperatorTake

Deposits an operator take proof for a peg-out transaction

*Validates the SPV proof and marks the slot as paid when operator takes over*

*Only callable when the peg status is KICKOFF and contract is unpaused*


```solidity
function registerOperatorTake(BtcTxSPVProof calldata _pegoutTxSPVProof) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_pegoutTxSPVProof`|`BtcTxSPVProof`|The BTC SPV proof of the peg-out transaction|


### registerOperatorWon

Deposits an operator won proof for a peg-out transaction

*Validates the SPV proof and marks the slot as paid when operator takes over*

*Only callable when the peg status is REVEALED and contract is unpaused*


```solidity
function registerOperatorWon(BtcTxSPVProof calldata _pegoutTxSPVProof) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_pegoutTxSPVProof`|`BtcTxSPVProof`|The BTC SPV proof of the operator won transaction|


### triggerOperatorTake

Triggers the operator take process for a peg-out when not all committee members sign within timeout


```solidity
function triggerOperatorTake(bytes32 _acceptPeginTxid) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_acceptPeginTxid`|`bytes32`|The accept peg-in transaction id for the peg-out|


### getOperatorTakeInfo

Gets temporary operator take information for a peg-out


```solidity
function getOperatorTakeInfo(bytes32 _acceptPeginTxid) external view returns (OperatorTakeInfo memory);
```

### getCancelUserTakeTxBlockNumber

Returns the bitcoin block number where the cancel user take tx was mined


```solidity
function getCancelUserTakeTxBlockNumber(bytes32 _acceptPeginTxid) external view returns (int256 blockNumber);
```

### takeTimeouts

Gets the timeout settings for a specific stream (auto-generated from public storage)


```solidity
function takeTimeouts(uint256 streamId) external view returns (uint256 userTake, uint256 operatorTake);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`streamId`|`uint256`|The stream identifier|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`userTake`|`uint256`|Timeout in seconds for user take operations|
|`operatorTake`|`uint256`|Timeout in seconds for operator take operations|


### setTakeTimeout

Sets the timeout settings for a specific stream

*Only callable by the contract owner*


```solidity
function setTakeTimeout(uint64 _streamId, TakeTimeout memory _timeout) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_streamId`|`uint64`|The stream identifier|
|`_timeout`|`TakeTimeout`|The new timeout settings|


## Events
### AdvanceFundsRegistered
Event emitted when advance funds are successfully registered


```solidity
event AdvanceFundsRegistered(
    bytes32 indexed blockHash,
    bytes32 indexed txid,
    bytes32 indexed acceptPeginTxid,
    bytes32 pegoutId,
    uint128 committeeId,
    StreamPosition streamInfo,
    CompactPubKey operatorTakePubKey
);
```

### CancelUserTakeRegistered
Event emitted when cancel user take spv proof is registered


```solidity
event CancelUserTakeRegistered(bytes32 indexed acceptPeginTxid);
```

### OperatorTakeTriggered
Event emitted when operator take is triggered


```solidity
event OperatorTakeTriggered(
    bytes32 indexed pegoutTxid,
    OperatorTakeInfo operatorTakeInfo,
    StreamPosition streamPosition,
    uint256 updatedAt,
    uint256 expireAt
);
```

### TakeTimeoutUpdated
Event emitted when the timeout settings are updated for a specific stream


```solidity
event TakeTimeoutUpdated(uint64 indexed streamId, TakeTimeout newTimeout);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`streamId`|`uint64`|The stream identifier|
|`newTimeout`|`TakeTimeout`|The new timeout settings|

### ReimbursementKickoffRegistered
Event emitted when reimbursement kickoff is successfully registered


```solidity
event ReimbursementKickoffRegistered(
    bytes32 indexed txid,
    bytes32 indexed acceptPeginTxid,
    bytes32 indexed pegoutId,
    uint128 committeeId,
    StreamPosition streamInfo,
    CompactPubKey operatorTakePubKey
);
```

## Errors
### WrongUserAmount
Thrown when the advance funds amount is lower than the expected peg-out amount


```solidity
error WrongUserAmount(uint256 actual, uint256 expected);
```

### ReimbursementKickoffTxidNotMatch
Thrown when the reimbursement kickoff txid does not match the expected value


```solidity
error ReimbursementKickoffTxidNotMatch(bytes32 actual, bytes32 expected);
```

### InputRevealedTxidNotMatch
Thrown when the input txid Operator Won transaction does not match the expected value


```solidity
error InputRevealedTxidNotMatch(bytes32 actual, bytes32 expected);
```

### OperatorTakeTxidNotMatch
Thrown when the operator take transaction id does not match the expected value


```solidity
error OperatorTakeTxidNotMatch(bytes32 actual, bytes32 expected);
```

### OperatorWonTxidNotMatch
Thrown when the operator won transaction id does not match the expected value


```solidity
error OperatorWonTxidNotMatch(bytes32 actual, bytes32 expected);
```

### OperatorTakeAddressNotMatch
Thrown when the operator address does not match the expected operator that should advance the funds


```solidity
error OperatorTakeAddressNotMatch(address expectedOperator, address actualOperator);
```

### InvalidKickoffInputCount
Thrown when the number of inputs in the kickoff transaction doesn't match the expected count


```solidity
error InvalidKickoffInputCount(uint256 actual, uint256 expected);
```

### InvalidSlotId
Thrown when the slot id in the kickoff transaction doesn't match the expected slot id


```solidity
error InvalidSlotId(uint32 actual, uint64 expected);
```

### ReimbursementKickoffBeforeAdvanceFunds
Thrown when the reimbursement kickoff transaction is mined before the advance funds transaction


```solidity
error ReimbursementKickoffBeforeAdvanceFunds(int256 advanceFundsBlockNumber, int256 reimbursementKickoffBlockNumber);
```

### OperatorTakeDataNotFound
Thrown when operator take data is not found for a given accept peg-in txid and operator address


```solidity
error OperatorTakeDataNotFound(bytes32 acceptPeginTxid, address operatorAddress);
```

### InvalidTimeoutsLength
Thrown when the per-stream timeout array has incorrect length


```solidity
error InvalidTimeoutsLength();
```

### InvalidTimeout
Thrown when an invalid timeout value is provided (zero timeout)


```solidity
error InvalidTimeout(uint256 timeout);
```

### UserTakeTimeoutNotExpired
Thrown when trying to trigger operator take before user take timeout has expired


```solidity
error UserTakeTimeoutNotExpired(uint256 createdAt, uint256 expireAt);
```

### OperatorTakeTimeoutNotExpired
Thrown when trying to trigger operator take before operator take timeout has expired


```solidity
error OperatorTakeTimeoutNotExpired(uint256 updatedAt, uint256 expireAt);
```

### UserTakeNotCancelled
Thrown when operator is trying to advance funds without having cancelled the user take flow


```solidity
error UserTakeNotCancelled(bytes32 acceptPeginTxid);
```

### AdvanceFundsBeforeCancelUserTake
Thrown when operator is trying to advance funds before cancelling user take flow


```solidity
error AdvanceFundsBeforeCancelUserTake(bytes32 acceptPeginTxid);
```

### CancelUserTakeAlreadyRegistered
Thrown when trying to register an already registered cancel user take spv proof


```solidity
error CancelUserTakeAlreadyRegistered(bytes32 acceptPeginTxid);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`acceptPeginTxid`|`bytes32`|The accept pegin txid associated with the pegout for which user take flow is already cancelled|

