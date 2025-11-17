# PauseManager
[Git Source](https://github.com/FairgateLabs/bitvmx-union-bridge-contracts/blob/b656e8c68a46e57c80c7029f9deb9e4b65b60046/src/PauseManager.sol)

**Inherits:**
[IPauseManager](/src/interfaces/IPauseManager.sol/interface.IPauseManager.md), [BaseProxy](/src/BaseProxy.sol/abstract.BaseProxy.md)

Centralized pause manager for all pausable contracts in the union bridge system

*This contract is responsible for pausing/unpausing all pausable contracts*


## State Variables
### peginManager
The PeginManager contract


```solidity
IPausable public peginManager;
```


### pegoutManager
The PegoutManager contract


```solidity
IPausable public pegoutManager;
```


### committeeRegistry
The CommitteeRegistry contract


```solidity
IPausable public committeeRegistry;
```


### memberRegistry
The MemberRegistry contract


```solidity
IPausable public memberRegistry;
```


## Functions
### constructor

**Note:**
oz-upgrades-unsafe-allow: constructor


```solidity
constructor();
```

### initialize

Initializes the PauseManager contract


```solidity
function initialize(
    address _initialOwner,
    address _peginManager,
    address _pegoutManager,
    address _committeeRegistry,
    address _memberRegistry
) external initializer;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_initialOwner`|`address`|The initial owner of the contract who can pause/unpause|
|`_peginManager`|`address`|The address of the PeginManager contract|
|`_pegoutManager`|`address`|The address of the PegoutManager contract|
|`_committeeRegistry`|`address`|The address of the CommitteeRegistry contract|
|`_memberRegistry`|`address`|The address of the MemberRegistry contract|


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

Returns true if any of the contracts is paused

*Returns true if at least one contract is paused*


```solidity
function areContractsPaused() external view returns (bool);
```

