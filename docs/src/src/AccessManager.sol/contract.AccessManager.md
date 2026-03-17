# AccessManager
[Git Source](https://github.com/temp-rsk/bitvmx-union-bridge-contracts/blob/ee0115174aa9f16d975ad140f940d23fb1883b23/src/AccessManager.sol)

**Inherits:**
[IAccessManager](/src/interfaces/IAccessManager.sol/interface.IAccessManager.md), [PauseManager](/src/PauseManager.sol/abstract.PauseManager.md)

Manages access control for the union bridge system

*Provides access control with pause manager contracts as the authorized accounts*

*Inherits from PauseManager to inherit the pause manager functionality*


## Functions
### initialize

Initializes the AccessManager contract

*Sets up the initial owner*

*Can only be called once during contract deployment*


```solidity
function initialize(address _initialOwner) public initializer;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_initialOwner`|`address`|The address that will be set as the initial owner|


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


### _revertIfNotTestnet


```solidity
function _revertIfNotTestnet() internal view;
```

### revertIfNotTestnet

Reverts if not called on testnet, regtest, or local network

*Used to protect testnet-only functions from being called on mainnet*


```solidity
function revertIfNotTestnet() external view;
```

