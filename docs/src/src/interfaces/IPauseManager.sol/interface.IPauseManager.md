# IPauseManager
[Git Source](https://github.com/temp-rsk/bitvmx-union-bridge-contracts/blob/bd6b4a28bf5973e554d9b7a237190a44cdd46b38/src/interfaces/IPauseManager.sol)

Interface for the centralized pause manager contract

*This contract is responsible for pausing/unpausing all pausable contracts in the system*


## Functions
### pause

Pauses all pausable contracts

*Only callable by the contract owner*


```solidity
function pause() external;
```

### unpause

Unpauses all pausable contracts

*Only callable by the contract owner*


```solidity
function unpause() external;
```

### areContractsPaused

Returns true if all contracts are paused, false if all are unpaused

*Reverts if contracts have inconsistent pause states*


```solidity
function areContractsPaused() external view returns (bool);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if all contracts are paused, false if all are unpaused|


### setCommitteeRegistry

Sets the Committee Registry contract address

*Only callable by the contract owner*


```solidity
function setCommitteeRegistry(address _committeeRegistry) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_committeeRegistry`|`address`|The address of the Committee Registry contract|


### setPeginManager

Sets the Pegin Manager contract address

*Only callable by the contract owner*


```solidity
function setPeginManager(address _peginManager) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_peginManager`|`address`|The address of the Pegin Manager contract|


### setPegoutManager

Sets the Pegout Manager contract address

*Only callable by the contract owner*


```solidity
function setPegoutManager(address _pegoutManager) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_pegoutManager`|`address`|The address of the Pegout Manager contract|


### setChallengeManager

Sets the Challenge Manager contract address

*Only callable by the contract owner*


```solidity
function setChallengeManager(address _challengeManager) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_challengeManager`|`address`|The address of the Challenge Manager contract|


### setOperatorTakeManager

Sets the OperatorTakeManager contract address

*Only callable by the contract owner*


```solidity
function setOperatorTakeManager(address _operatorTakeManager) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_operatorTakeManager`|`address`|The address of the OperatorTakeManager contract|


### setMemberRegistry

Sets the member registry contract address

*Only callable by the contract owner*


```solidity
function setMemberRegistry(address _memberRegistry) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_memberRegistry`|`address`|The address of the Member Registry contract|


### setRbtcBridge

Sets the rbtc bridge contract address

*Only callable by the contract owner*


```solidity
function setRbtcBridge(address _rbtcBridge) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_rbtcBridge`|`address`|The address of the Rbtc Bridge contract|


## Events
### PausableContractUpdated
Emitted when a pausable contract address is updated


```solidity
event PausableContractUpdated(string contractName, address newAddress);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`contractName`|`string`|The name of the contract that was updated|
|`newAddress`|`address`|The new address of the contract|

## Errors
### _InconsistentPauseState
Error thrown when the pause states of contracts are inconsistent

*This error is thrown when not all pausable contracts have the same pause state*


```solidity
error _InconsistentPauseState();
```

### InvalidZeroAddress
Thrown when the value is zero


```solidity
error InvalidZeroAddress();
```

### AlreadySet
Thrown when the value is already set to a non-zero address


```solidity
error AlreadySet();
```

