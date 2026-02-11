# IPegoutManager
[Git Source](https://github.com/temp-rsk/bitvmx-union-bridge-contracts/blob/6a9ea8ca3ca82c82894d3db0e338e4bf6bb46de8/src/interfaces/IPegoutManager.sol)

Interface for managing peg-out operations


## Functions
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


### setUserTakeTimeout

Sets the timeout duration for user take operations

*Only callable by the contract owner*

*Emits UserTakeTimeoutUpdated event upon successful update*

*Reverts if the timeout is zero*


```solidity
function setUserTakeTimeout(uint256 _timeout) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_timeout`|`uint256`|The new timeout duration in seconds|


### setOperatorTakeTimeout

Sets the timeout duration for operator take operations

*Only callable by the contract owner*

*Emits OperatorTakeTimeoutUpdated event upon successful update*

*Reverts if the timeout is zero*


```solidity
function setOperatorTakeTimeout(uint256 _timeout) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_timeout`|`uint256`|The new timeout duration in seconds|


### userTakeTimeout

Gets the current timeout duration for user take operations


```solidity
function userTakeTimeout() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The timeout duration in seconds|


### operatorTakeTimeout

Gets the current timeout duration for operator take operations


```solidity
function operatorTakeTimeout() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The timeout duration in seconds|


### registerAdvanceFunds

Registers the advance funds transaction submitted by the operator

*Validates the SPV proof and updated the peg-out status accordingly*


```solidity
function registerAdvanceFunds(bytes32 acceptPeginTxid, BtcTxSPVProof calldata _advanceFunds) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`acceptPeginTxid`|`bytes32`|The accept peg-in transaction id that it's being advanced|
|`_advanceFunds`|`BtcTxSPVProof`|The BTC SPV proof of the advance funds transaction|


### registerReimbursementKickoff

Registers the reimbursement kickoff transaction submitted by the operator

*Validates the SPV proof and updates the peg-out status accordingly*


```solidity
function registerReimbursementKickoff(bytes32 acceptPeginTxid, BtcTxSPVProof calldata _kickoffSPV) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`acceptPeginTxid`|`bytes32`|The accept peg-in transaction id that it's being reimbursed|
|`_kickoffSPV`|`BtcTxSPVProof`|The BTC SPV proof of the reimbursement kickoff transaction|


### registerOperatorTake

Deposits an operator take proof for a peg-out transaction

*Validates the SPV proof and marks the slot as paid when operator takes over*

*Only callable when the peg status is KICKOFF and contract is unpaused*

*Emits PegoutRegistered event upon successful deposit*

*Only callable when contract is unpaused*


```solidity
function registerOperatorTake(BtcTxSPVProof calldata _pegoutTxSPVProof) external;
```

### registerOperatorWon

Deposits an operator won proof for a peg-out transaction

*Validates the SPV proof and marks the slot as paid when operator takes over*

*Only callable when the peg status is OPERATOR_TAKE*

*Emits PegoutRegistered event upon successful deposit*

*Only callable when contract is unpaused*


```solidity
function registerOperatorWon(BtcTxSPVProof memory _pegoutTxSPVProof) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_pegoutTxSPVProof`|`BtcTxSPVProof`|The BTC SPV proof of the operator won transaction|


### triggerOperatorTake

Triggers the operator take process for a peg-out when not all committee members sign within timeout

*This function can be called after a User Take expiration or after an Operator Take expiration*

*Each case has its own timeout and before triggering the operator take (after a User Take expiration)*

*signatures should be checked to see if the User Take was already signed*

*Partial signatures are used to skip those operators that have not signed the User Take*

*Emits OperatorTakeTriggered event upon successful triggering*

*Only callable when contract is unpaused*


```solidity
function triggerOperatorTake(bytes32 _pegoutTxid) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_pegoutTxid`|`bytes32`|The transaction id of the peg-out request|


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
|`acceptPeginTxid`|`bytes32`|The hash of the original accept peg-in transaction|
|`committeeId`|`uint128`|The ID of the committee responsible for this peg-out|
|`streamInfo`|`StreamPosition`|The stream position information related to this peg-out|

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
    bytes32 operatorTakePubKey
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`blockHash`|`bytes32`|The Bitcoin block hash containing the advance funds transaction|
|`txid`|`bytes32`|The hash of the advance funds transaction|
|`acceptPeginTxid`|`bytes32`|The hash of the original accept peg-in transaction|
|`pegoutId`|`bytes32`|The unique identifier for this peg-out operation|
|`committeeId`|`uint128`|The ID of the committee responsible for this advance funds|
|`streamInfo`|`StreamPosition`|The stream position information related to this advance funds|
|`operatorTakePubKey`|`bytes32`|The public key of the operator that took the advance funds|

### ReimbursementKickoffRegistered
Event emitted when reimbursement kickoff is successfully registered


```solidity
event ReimbursementKickoffRegistered(
    bytes32 indexed txid,
    bytes32 indexed acceptPeginTxid,
    bytes32 indexed pegoutId,
    uint128 committeeId,
    StreamPosition streamInfo,
    bytes32 operatorTakePubKey
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`txid`|`bytes32`|The hash of the reimbursement kickoff transaction|
|`acceptPeginTxid`|`bytes32`|The hash of the original accept peg-in transaction|
|`pegoutId`|`bytes32`|The unique identifier for this peg-out operation|
|`committeeId`|`uint128`|The ID of the committee responsible for this reimbursement kickoff|
|`streamInfo`|`StreamPosition`|The stream position information related to this reimbursement kickoff|
|`operatorTakePubKey`|`bytes32`|The public key of the operator that took the advance funds|

### UserTakeTimeoutUpdated
Event emitted when the user take timeout is updated


```solidity
event UserTakeTimeoutUpdated(uint256 newTimeout);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newTimeout`|`uint256`|The new timeout duration in seconds|

### OperatorTakeTimeoutUpdated
Event emitted when the operator take timeout is updated


```solidity
event OperatorTakeTimeoutUpdated(uint256 newTimeout);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newTimeout`|`uint256`|The new timeout duration in seconds|

### OperatorTakeTriggered
Event emitted when operator take is triggered for a peg-out


```solidity
event OperatorTakeTriggered(
    bytes32 indexed pegoutTxid,
    PegoutTempInfo pegoutInfo,
    StreamPosition streamPosition,
    uint256 updatedAt,
    uint256 expireAt
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`pegoutTxid`|`bytes32`|The transaction id of the peg-out request|
|`pegoutInfo`|`PegoutTempInfo`|Complete pegout temporary information including operator details|
|`streamPosition`|`StreamPosition`|Stream position information including slot ID|
|`updatedAt`|`uint256`|The timestamp when the operator take was triggered|
|`expireAt`|`uint256`|The timestamp when the operator take timeout expires|

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

### InvalidTimeout
Thrown when an invalid timeout value is provided (zero timeout)


```solidity
error InvalidTimeout(uint256 timeout);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`timeout`|`uint256`|The invalid timeout value that was provided|

### UserTakeTimeoutNotExpired
Thrown when trying to trigger operator take before user take timeout has expired


```solidity
error UserTakeTimeoutNotExpired(uint256 createdAt, uint256 expireAt);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`createdAt`|`uint256`|The timestamp when the user take was created|
|`expireAt`|`uint256`|The timestamp when the user take timeout expires|

### UserTakeAlreadySigned
Thrown when trying to trigger operator take but user take was already signed


```solidity
error UserTakeAlreadySigned(bytes32 pegoutTxid);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`pegoutTxid`|`bytes32`|The signature hash of the peg-out request|

### OperatorTakeTimeoutNotExpired
Thrown when trying to trigger operator take before operator take timeout has expired


```solidity
error OperatorTakeTimeoutNotExpired(uint256 createdAt, uint256 expireAt);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`createdAt`|`uint256`|The timestamp when the operator take was updated|
|`expireAt`|`uint256`|The timestamp when the operator take timeout expires|

### PegoutTxidNotFound
Thrown when a peg-out signature hash is not found in the system


```solidity
error PegoutTxidNotFound(bytes32 pegoutTxid);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`pegoutTxid`|`bytes32`|The signature hash that was not found|

### OperatorTakeAddressNotMatch
Thrown when the operator address does not match the expected operator that should advance the funds


```solidity
error OperatorTakeAddressNotMatch(address expectedOperator, address actualOperator);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`expectedOperator`|`address`|The expected operator address that should take the pegout|
|`actualOperator`|`address`|The actual operator address that was provided|

### ReimbursementKickoffBeforeAdvanceFunds
Thrown when the reimbursement kickoff transaction is mined before the advance funds transaction


```solidity
error ReimbursementKickoffBeforeAdvanceFunds(int256 advanceFundsBlockNumber, int256 reimbursementKickoffBlockNumber);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`advanceFundsBlockNumber`|`int256`|The block number when advance funds was mined|
|`reimbursementKickoffBlockNumber`|`int256`|The block number when reimbursement kickoff was mined|

### WrongUserAmount
Thrown when the advance funds amount is lower than the expected peg-out amount


```solidity
error WrongUserAmount(uint256 actual, uint256 expected);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`actual`|`uint256`|The actual amount in satoshis of the advance funds transaction|
|`expected`|`uint256`|The expected amount in satoshis that should be advanced|

### ReimbursementKickoffTxidNotMatch
Thrown when the reimbursement kickoff txid does not match the expected value


```solidity
error ReimbursementKickoffTxidNotMatch(bytes32 actual, bytes32 expected);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`actual`|`bytes32`|The actual reimbursement kickoff txid provided|
|`expected`|`bytes32`|The expected reimbursement kickoff txid|

### InputRevealedTxidNotMatch
Thrown when the input txid Operator Won transaction does not match the expected value


```solidity
error InputRevealedTxidNotMatch(bytes32 actual, bytes32 expected);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`actual`|`bytes32`|The actual input txid provided|
|`expected`|`bytes32`|The expected input txid|

### OperatorTakeDataNotFound
Thrown when operator take data is not found for a given accept peg-in txid and operator address


```solidity
error OperatorTakeDataNotFound(bytes32 acceptPeginTxid, address operatorAddress);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`acceptPeginTxid`|`bytes32`|The accept peg-in transaction id|
|`operatorAddress`|`address`|The operator address for which the data was not found|

### OperatorTakeTxidNotMatch
Thrown when the operator take transaction id does not match the expected value


```solidity
error OperatorTakeTxidNotMatch(bytes32 actual, bytes32 expected);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`actual`|`bytes32`|The actual operator take transaction id provided|
|`expected`|`bytes32`|The expected operator take transaction id|

### OperatorWonTxidNotMatch
Thrown when the operator won transaction id does not match the expected value


```solidity
error OperatorWonTxidNotMatch(bytes32 actual, bytes32 expected);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`actual`|`bytes32`|The actual operator won transaction id provided|
|`expected`|`bytes32`|The expected operator won transaction id|

### InvalidKickoffInputCount
Thrown when the number of inputs in the kickoff transaction doesn't match the expected count


```solidity
error InvalidKickoffInputCount(uint256 actual, uint256 expected);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`actual`|`uint256`|The actual number of inputs|
|`expected`|`uint256`|The expected number of inputs|

### InvalidSlotId
Thrown when the slot id in the kickoff transaction doesn't match the expected slot id


```solidity
error InvalidSlotId(uint32 actual, uint64 expected);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`actual`|`uint32`|The actual slot id from the transaction input|
|`expected`|`uint64`|The expected slot id from the stream position|

