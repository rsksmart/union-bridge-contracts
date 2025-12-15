# IPauseManager
[Git Source](https://github.com/temp-rsk/bitvmx-union-bridge-contracts/blob/96535706e496364789ce242b18e17052bb6e424e/src/interfaces/IPauseManager.sol)

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

