# PauseManager
[Git Source](https://github.com/rsksmart/union-bridge-contracts/blob/68c14faa89612dfba1b7e9abf29455625661476f/src/PauseManager.sol)

**Inherits:**
[IPauseManager](/src/interfaces/IPauseManager.sol/interface.IPauseManager.md), [BaseProxy](/src/BaseProxy.sol/abstract.BaseProxy.md)

Centralized pause manager for all pausable contracts in the union bridge system

*This contract is responsible for pausing/unpausing all pausable contracts*


## State Variables
### peginManager
The PeginManager contract


```solidity
address public peginManager;
```


### pegoutManager
The PegoutManager contract


```solidity
address public pegoutManager;
```


### committeeRegistry
The CommitteeRegistry contract


```solidity
address public committeeRegistry;
```


### memberRegistry
The MemberRegistry contract


```solidity
address public memberRegistry;
```


### rbtcBridge
The RbtcBridge contract


```solidity
address public rbtcBridge;
```


### challengeManager
The ChallengeManager contract


```solidity
address public challengeManager;
```


## Functions
### __PauseManager_init

Initializes the PauseManager contract


```solidity
function __PauseManager_init(address _initialOwner) internal initializer;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_initialOwner`|`address`|The initial owner of the contract who can pause/unpause|


### pause

Pauses all pausable contracts

*Only callable by the contract owner*


```solidity
function pause() external onlyOwner;
```

### unpause

Unpauses all pausable contracts

*Only callable by the contract owner*


```solidity
function unpause() external onlyOwner;
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
function setCommitteeRegistry(address _committeeRegistry) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_committeeRegistry`|`address`|The address of the Committee Registry contract|


### setPeginManager

Sets the Pegin Manager contract address

*Only callable by the contract owner*


```solidity
function setPeginManager(address _peginManager) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_peginManager`|`address`|The address of the Pegin Manager contract|


### setPegoutManager

Sets the Pegout Manager contract address

*Only callable by the contract owner*


```solidity
function setPegoutManager(address _pegoutManager) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_pegoutManager`|`address`|The address of the Pegout Manager contract|


### setChallengeManager

Sets the Pegout Manager contract address

*Only callable by the contract owner*


```solidity
function setChallengeManager(address _challengeManager) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_challengeManager`|`address`|The address of the Challenge Manager contract|


### setMemberRegistry

Sets the member registry contract address

*Only callable by the contract owner*


```solidity
function setMemberRegistry(address _memberRegistry) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_memberRegistry`|`address`|The address of the Member Registry contract|


### setRbtcBridge

Sets the rbtc bridge contract address

*Only callable by the contract owner*


```solidity
function setRbtcBridge(address _rbtcBridge) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_rbtcBridge`|`address`|The address of the Rbtc Bridge contract|


