# IPauseManager
[Git Source](https://github.com/temp-rsk/bitvmx-union-bridge-contracts/blob/0c819fa3fad6abf73f5f2a830cc21b001080582f/src/interfaces/IPauseManager.sol)

Interface for the centralized pause manager contract

*This contract is responsible for pausing/unpausing all pausable contracts in the system*


## Functions
### initialize

Initializes the PauseManager contract


```solidity
function initialize(
    address _initialOwner,
    address _peginManager,
    address _pegoutManager,
    address _committeeRegistry,
    address _memberRegistry
) external;
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
function pause() external;
```

### unpause

Unpauses all pausable contracts

*Only callable by the contract owner*


```solidity
function unpause() external;
```

### areContractsPaused

Returns true if any of the contracts is paused

*Returns true if at least one contract is paused*


```solidity
function areContractsPaused() external view returns (bool);
```

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
### ZeroAddress
Error thrown when a zero address is provided


```solidity
error ZeroAddress();
```

### _InconsistentPauseState
Error thrown when the pause states of contracts are inconsistent

*This error is thrown when not all pausable contracts have the same pause state*


```solidity
error _InconsistentPauseState();
```

