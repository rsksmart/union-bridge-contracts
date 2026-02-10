# IPausable
[Git Source](https://github.com/temp-rsk/bitvmx-union-bridge-contracts/blob/6a9ea8ca3ca82c82894d3db0e338e4bf6bb46de8/src/interfaces/IPausable.sol)

Interface for pauser in the union bridge

*This interface provides error definitions for pauser operations*

*Used to implement open zeppelin's pauser functionality*


## Functions
### pause

Pauses the contract

*Only callable by the pauser*


```solidity
function pause() external;
```

### unpause

Unpauses the contract

*Only callable by the pauser*


```solidity
function unpause() external;
```

### isPaused

Returns true if the contract is paused, and false otherwise.


```solidity
function isPaused() external view returns (bool);
```

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
### InvalidZeroAddress
Thrown when an address is zero


```solidity
error InvalidZeroAddress();
```

### UnauthorizedPauser
Error thrown when an account is not authorized as pauser


```solidity
error UnauthorizedPauser(address account);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|The unauthorized account|

