# IChallengeManager
[Git Source](https://github.com/temp-rsk/bitvmx-union-bridge-contracts/blob/835a0374fad05fe95d66ed5d56f02d5826093237/src/interfaces/IChallengeManager.sol)

Interface for managing challenge operations


## Functions
### getChallengeTempInfo

Gets the temporary challenge information for a given accept peg-in transaction id


```solidity
function getChallengeTempInfo(bytes32 _acceptPeginTxid) external view returns (ChallengeTempInfo memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_acceptPeginTxid`|`bytes32`|The accept peg-in transaction id|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`ChallengeTempInfo`|The temporary challenge information|


### registerChallenge

Registers a challenge for a peg-out transaction

*Validates the SPV proof and updates the peg-out status accordingly*


```solidity
function registerChallenge(bytes32 acceptPeginTxid, BtcTxSPVProof calldata _challenge) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`acceptPeginTxid`|`bytes32`|The accept peg-in transaction id that is being challenged|
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
|`_acceptPeginTxid`|`bytes32`|The accept peg-in transaction id that is being revealed|
|`_inputRevealed`|`BtcTxSPVProof`|The BTC SPV proof of the input revealed transaction|


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
|`acceptPeginTxid`|`bytes32`|The hash of the original accept peg-in transaction|
|`committeeId`|`uint128`|The ID of the committee responsible for this challenge|
|`streamInfo`|`StreamPosition`|The stream position information related to this challenge|

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
|`acceptPeginTxid`|`bytes32`|The hash of the original accept peg-in transaction|
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

