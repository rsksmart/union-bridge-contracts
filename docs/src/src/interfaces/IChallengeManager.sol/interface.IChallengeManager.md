# IChallengeManager
[Git Source](https://github.com/rsksmart/union-bridge-contracts/blob/dd34207db3c68e4260aba3e2d2660c73733e6970/src/interfaces/IChallengeManager.sol)

Interface for managing challenge operations


## Functions
### getChallengeInfo

Gets the challenge information for a given accept peg-in transaction id


```solidity
function getChallengeInfo(bytes32 _acceptPeginTxid) external view returns (ChallengeInfo memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_acceptPeginTxid`|`bytes32`|The accept peg-in transaction id|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`ChallengeInfo`|The challenge information|


### registerChallenge

Registers a challenge for a peg-out transaction

*Validates the SPV proof and updates the peg-out status accordingly*


```solidity
function registerChallenge(bytes32 _acceptPeginTxid, BtcTxSPVProof calldata _challenge) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_acceptPeginTxid`|`bytes32`|The accept peg-in transaction id that is being challenged|
|`_challenge`|`BtcTxSPVProof`|The BTC SPV proof of the challenge transaction|


### registerInputRevealed

Registers an input revealed for a challenge transaction

*Validates the SPV proof and updates the challenge status accordingly*


```solidity
function registerInputRevealed(bytes32 _acceptPeginTxid, BtcTxSPVProof memory _inputRevealed) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_acceptPeginTxid`|`bytes32`|The accept peg-in transaction id that is being challenged|
|`_inputRevealed`|`BtcTxSPVProof`|The BTC SPV proof of the input revealed transaction|


### registerInputNotRevealed

Registers an input not revealed for a challenge transaction

*Validates the SPV proof and updates the challenge status accordingly*


```solidity
function registerInputNotRevealed(bytes32 _acceptPeginTxid, BtcTxSPVProof calldata _inputNotRevealed) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_acceptPeginTxid`|`bytes32`|The accept peg-in transaction id that is being challenged|
|`_inputNotRevealed`|`BtcTxSPVProof`|The BTC SPV proof of the input not revealed transaction|


### registerStopOperatorWon

Registers a stop operator won for a reveal transaction

*Validates the SPV proof and updates the challenge status accordingly*


```solidity
function registerStopOperatorWon(bytes32 _acceptPeginTxid, BtcTxSPVProof calldata _stopOperatorWon) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_acceptPeginTxid`|`bytes32`|The accept peg-in transaction id that is being challenged|
|`_stopOperatorWon`|`BtcTxSPVProof`|The BTC SPV proof of the stop operator won transaction|


## Events
### ChallengeRegistered
Event emitted when a challenge is registered for a peg-out


```solidity
event ChallengeRegistered(
    bytes32 indexed txid, bytes32 indexed acceptPeginTxid, uint128 committeeId, StreamPosition streamInfo
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`txid`|`bytes32`|The hash of the challenge transaction|
|`acceptPeginTxid`|`bytes32`|The txid of the original accept peg-in transaction|
|`committeeId`|`uint128`|The ID of the committee responsible for this challenge|
|`streamInfo`|`StreamPosition`|The stream position information related to this challenge|

### InputNotRevealedRegistered
Event emitted when an input is not revealed for a challenge


```solidity
event InputNotRevealedRegistered(
    bytes32 indexed txid, bytes32 indexed acceptPeginTxid, uint128 committeeId, StreamPosition streamInfo
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`txid`|`bytes32`|The hash of the input not revealed transaction|
|`acceptPeginTxid`|`bytes32`|The txid of the original accept peg-in transaction|
|`committeeId`|`uint128`|The ID of the committee responsible for this pegout|
|`streamInfo`|`StreamPosition`|The stream position information related to this pegout|

### StopOperatorWonRegistered
Event emitted when a stop operator won is registered for a reveal transaction


```solidity
event StopOperatorWonRegistered(
    bytes32 indexed txid, bytes32 indexed acceptPeginTxid, uint128 committeeId, StreamPosition streamInfo
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`txid`|`bytes32`|The hash of the stop operator won transaction|
|`acceptPeginTxid`|`bytes32`|The txid of the original accept peg-in transaction|
|`committeeId`|`uint128`|The ID of the committee responsible for this pegout|
|`streamInfo`|`StreamPosition`|The stream position information related to this pegout|

### RevealRegistered
Event emitted when an input is revealed for a challenge


```solidity
event RevealRegistered(
    bytes32 indexed txid, bytes32 indexed acceptPeginTxid, uint128 committeeId, StreamPosition streamInfo
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`txid`|`bytes32`|The hash of the reveal transaction|
|`acceptPeginTxid`|`bytes32`|The txid of the original accept peg-in transaction|
|`committeeId`|`uint128`|The ID of the committee responsible for this pegout|
|`streamInfo`|`StreamPosition`|The stream position information related to this pegout|

## Errors
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

### ChallengeTxidNotMatch
Thrown when the challenge transaction id does not match the expected value


```solidity
error ChallengeTxidNotMatch(bytes32 actual, bytes32 expected);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`actual`|`bytes32`|The actual transaction id|
|`expected`|`bytes32`|The expected transaction id|

### RevealTxidNotMatch
Thrown when the reveal transaction id does not match the expected value


```solidity
error RevealTxidNotMatch(bytes32 input1txid, bytes32 input2txid, bytes32 expectedTxid);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`input1txid`|`bytes32`|The txid for the first input|
|`input2txid`|`bytes32`|The txid for the second input|
|`expectedTxid`|`bytes32`|The expected transaction id|

### InvalidChallengeInputCount
Thrown when the number of inputs in a challenge transaction is incorrect


```solidity
error InvalidChallengeInputCount(uint256 actual, uint256 expected);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`actual`|`uint256`|The actual number of inputs found|
|`expected`|`uint256`|The expected number of inputs|

### InvalidInputNotRevealedInputCount
Thrown when the number of inputs in an input not revealed transaction is incorrect


```solidity
error InvalidInputNotRevealedInputCount(uint256 actual, uint256 expected);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`actual`|`uint256`|The actual number of inputs found|
|`expected`|`uint256`|The expected number of inputs|

### InvalidInputNotRevealedOutputCount
Thrown when the number of outputs in an input not revealed transaction is incorrect


```solidity
error InvalidInputNotRevealedOutputCount(uint256 actual, uint256 expected);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`actual`|`uint256`|The actual number of outputs found|
|`expected`|`uint256`|The expected number of outputs (one speedup per committee member)|

### InvalidRevealedInputCount
Thrown when the number of inputs in a input reveal transaction is incorrect


```solidity
error InvalidRevealedInputCount(uint256 actual, uint256 expected);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`actual`|`uint256`|The actual number of inputs found|
|`expected`|`uint256`|The expected number of inputs|

### InvalidRevealedOutputCount
Thrown when the number of outputs in an input reveal transaction is incorrect


```solidity
error InvalidRevealedOutputCount(uint256 actual, uint256 expected);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`actual`|`uint256`|The actual number of outputs found|
|`expected`|`uint256`|The expected number of outputs|

### NoChallengeRegistered
Thrown when there is no challenge registered for the given accept peg-in transaction id


```solidity
error NoChallengeRegistered(bytes32 acceptPeginTxid);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`acceptPeginTxid`|`bytes32`|The accept peg-in transaction id|

### InvalidStopOperatorWonTxid
Thrown when the stop operator won transaction id is invalid


```solidity
error InvalidStopOperatorWonTxid(bytes32 txid);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`txid`|`bytes32`|The invalid transaction id|

### InvalidStopOperatorWonInputCount
Thrown when the number of inputs in a stop operator won transaction is incorrect


```solidity
error InvalidStopOperatorWonInputCount(uint256 actual, uint256 expected);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`actual`|`uint256`|The actual number of inputs found|
|`expected`|`uint256`|The expected number of inputs|

