# Pausable
[Git Source](https://github.com/temp-rsk/bitvmx-union-bridge-contracts/blob/0c819fa3fad6abf73f5f2a830cc21b001080582f/src/Pausable.sol)

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
function __Pauser_init() internal initializer;
```

### onlyPauser

Modifier to restrict access to the Pausable

*Reverts if the caller is not the Pauser*


```solidity
modifier onlyPauser();
```

### pause

Pauses the contract

*Only callable by the pausable*


```solidity
function pause() external onlyPauser;
```

### unpause

Unpauses the contract

*Only callable by the pausable*


```solidity
function unpause() external onlyPauser;
```

### isPaused

Returns true if the contract is paused, and false otherwise.

*Returns true if the contract is paused, and false otherwise.*


```solidity
function isPaused() public view returns (bool);
```

### setPauser

Sets a new pauser address

*Should be overridden by child contracts to add access control (e.g., onlyOwner)*


```solidity
function setPauser(address _newPauser) public virtual;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_newPauser`|`address`|The new pauser address|


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


## Events
### PauserUpdated
Event emitted when the pauser is updated


```solidity
event PauserUpdated(address newPauser);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newPauser`|`address`|The new pauser address|

## Errors
### UnauthorizedPauser
Error thrown when an account is not authorized as pauser


```solidity
error UnauthorizedPauser(address account);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|The unauthorized account|

### ZeroAddress
Error thrown when a zero address is provided


```solidity
error ZeroAddress();
```

