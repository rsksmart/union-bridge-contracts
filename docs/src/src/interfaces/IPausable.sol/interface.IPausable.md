# IPausable
[Git Source](https://github.com/temp-rsk/bitvmx-union-bridge-contracts/blob/4c35e62294ee16f56ba26d52283a5d84868fbd84/src/interfaces/IPausable.sol)

Interface for pauser in the union bridge

*This interface provides error definitions for pauser operations*

*Used to implement open zeppelin's pauser functionality*


## Functions
### pause

External functions to handle pauser pauses


```solidity
function pause() external;
```

### unpause


```solidity
function unpause() external;
```

### isPaused

*Returns true if the contract is paused, and false otherwise.*


```solidity
function isPaused() external view returns (bool);
```

