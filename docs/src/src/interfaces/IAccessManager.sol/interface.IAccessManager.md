# IAccessManager
[Git Source](https://github.com/rsksmart/union-bridge-contracts/blob/6c85aeb17a23ee9d675a92f8655a551ecca7b4c9/src/interfaces/IAccessManager.sol)

Interface for access control in the union bridge

*This interface provides error definitions for access control operations*

*Used to ensure proper authorization for sensitive operations*


## Functions
### canModifyPegStatus

Requires the caller to have permissions to modify the peg status

*Reverts if the caller does not have permissions to modify the peg status*


```solidity
function canModifyPegStatus(address _caller) external view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_caller`|`address`|The address of the caller|


### canCreateCommittee

Requires the caller to have permissions to create a committee

*Reverts if the caller does not have permissions to create a committee*


```solidity
function canCreateCommittee(address _caller) external view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_caller`|`address`|The address of the caller|


### canSelectTakeOperator

Requires the caller to have permissions to select a take operator

*Reverts if the caller does not have permissions to select a take operator*


```solidity
function canSelectTakeOperator(address _caller) external view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_caller`|`address`|The address of the caller|


### canReleaseCommittee

Requires the caller to have permissions to release a committee

*Reverts if the caller does not have permissions to release a committee*


```solidity
function canReleaseCommittee(address _caller) external view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_caller`|`address`|The address of the caller|


### canCreatePacket

Requires the caller to have permissions to create a packet

*Reverts if the caller does not have permissions to create a packet*


```solidity
function canCreatePacket(address _caller) external view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_caller`|`address`|The address of the caller|


### canMintRbtc

Requires the caller to have permissions to mint RBTC

*Reverts if the caller does not have permissions to mint RBTC*


```solidity
function canMintRbtc(address _caller) external view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_caller`|`address`|The address of the caller|


### canBurnRbtc

Requires the caller to have permissions to burn RBTC

*Reverts if the caller does not have permissions to burn RBTC*


```solidity
function canBurnRbtc(address _caller) external view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_caller`|`address`|The address of the caller|


### canInitSignatures

Requires the caller to have permissions to initialize signatures

*Reverts if the caller does not have permissions to initialize signatures*


```solidity
function canInitSignatures(address _caller) external view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_caller`|`address`|The address of the caller|


### canInitOperatorTakeTxids

Requires the caller to have permissions to initialize operator take txids

*Reverts if the caller does not have permissions to initialize operator take txids*


```solidity
function canInitOperatorTakeTxids(address _caller) external view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_caller`|`address`|The address of the caller|


### canModifyCandidatesForStream

Requires the caller to have permissions to modify candidates for a stream

*Reverts if the caller does not have permissions to modify candidates for a stream*


```solidity
function canModifyCandidatesForStream(address _caller) external view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_caller`|`address`|The address of the caller|


### canSetBaseEvent

Requires the caller to have permissions to set the base event

*Reverts if the caller does not have permissions to set the base event*


```solidity
function canSetBaseEvent(address _caller) external view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_caller`|`address`|The address of the caller|


### revertIfNotChallengeManager

Requires the caller to be the challenge manager

*Reverts if the caller is not the challenge manager*


```solidity
function revertIfNotChallengeManager(address _caller) external view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_caller`|`address`|The address of the caller|


### revertIfNotTestnet

Reverts if not called on testnet, regtest, or local network

*Used to protect testnet-only functions from being called on mainnet*


```solidity
function revertIfNotTestnet() external view;
```

## Errors
### UnauthorizedToCreateCommittee
Thrown when an account is not authorized to create a committee


```solidity
error UnauthorizedToCreateCommittee(address _caller);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_caller`|`address`|The address of the unauthorized account|

### UnauthorizedToReleaseCommittee
Thrown when an account is not authorized to release a committee


```solidity
error UnauthorizedToReleaseCommittee(address _caller);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_caller`|`address`|The address of the unauthorized account|

### UnauthorizedToSelectTakeOperator
Thrown when an account is not authorized to select a take operator


```solidity
error UnauthorizedToSelectTakeOperator(address _caller);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_caller`|`address`|The address of the unauthorized account|

### UnauthorizedToModifyPegStatus
Thrown when an account is not authorized to modify the peg status


```solidity
error UnauthorizedToModifyPegStatus(address _caller);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_caller`|`address`|The address of the unauthorized account|

### UnauthorizedToCreatePacket
Thrown when an account is not authorized to create a packet


```solidity
error UnauthorizedToCreatePacket(address _caller);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_caller`|`address`|The address of the unauthorized account|

### UnauthorizedToMintRbtc
Thrown when an account is not authorized to mint RBTC


```solidity
error UnauthorizedToMintRbtc(address _caller);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_caller`|`address`|The address of the unauthorized account|

### UnauthorizedToBurnRbtc
Thrown when an account is not authorized to burn RBTC


```solidity
error UnauthorizedToBurnRbtc(address _caller);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_caller`|`address`|The address of the unauthorized account|

### UnauthorizedToInitSignatures
Thrown when an account is not authorized to initialize signatures


```solidity
error UnauthorizedToInitSignatures(address _caller);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_caller`|`address`|The address of the unauthorized account|

### UnauthorizedToInitOperatorTakeTxids
Thrown when an account is not authorized to initialize operator take txids


```solidity
error UnauthorizedToInitOperatorTakeTxids(address _caller);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_caller`|`address`|The address of the unauthorized account|

### UnauthorizedToModifyCandidatesForStream
Thrown when an account is not authorized to modify candidates for a stream


```solidity
error UnauthorizedToModifyCandidatesForStream(address _caller);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_caller`|`address`|The address of the unauthorized account|

### UnauthorizedToSetBaseEvent
Thrown when an account is not authorized to set the base event


```solidity
error UnauthorizedToSetBaseEvent(address _caller);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_caller`|`address`|The address of the unauthorized account|

### CallerIsNotChallengeManager
Thrown when an account is not the challenge manager


```solidity
error CallerIsNotChallengeManager(address _caller);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_caller`|`address`|The address of the unauthorized account|

### TestnetOnlyFunction
Thrown when a testnet-only function is called on mainnet


```solidity
error TestnetOnlyFunction();
```

