# Pausable
[Git Source](https://github.com/temp-rsk/bitvmx-union-bridge-contracts/blob/aa0c5b500b0a03f68164877ee0ab01eebfbdfa68/src/Pausable.sol)

**Inherits:**
[IPausable](/src/interfaces/IPausable.sol/interface.IPausable.md), PausableUpgradeable

Base contract that provides pause/unpause functionality with a dedicated pauser role

*Inherits from OpenZeppelin's PausableUpgradeable and adds a pauser role*


## State Variables
### pauser
The address that can pause and unpause the contract


```solidity
address public pauser;
```


## Functions
### constructor

**Note:**
oz-upgrades-unsafe-allow: constructor


```solidity
constructor();
```

### __Pauser_init

Initializes the Pausable contract

*Can only be called once during contract deployment*


```solidity
function __Pauser_init(address _newPauser) internal onlyInitializing;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_newPauser`|`address`|The new pauser address|


### onlyPauser

Modifier to restrict access to the Pausable

*Reverts if the caller is not the Pauser*


```solidity
modifier onlyPauser();
```

### pause

Pauses the contract

*Only callable by the pauser*


```solidity
function pause() external onlyPauser;
```

### unpause

Unpauses the contract

*Only callable by the pauser*


```solidity
function unpause() external onlyPauser;
```

### isPaused

Returns true if the contract is paused, and false otherwise.


```solidity
function isPaused() public view returns (bool);
```

### _onlyPauser

Internal function to check if an account is the pauser

*Reverts with UnauthorizedPauser if the account is not the pauser*


```solidity
function _onlyPauser(address _account) internal view virtual;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_account`|`address`|The account to check|


