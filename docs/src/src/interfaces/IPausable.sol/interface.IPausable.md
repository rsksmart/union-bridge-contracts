# IPausable
[Git Source](https://github.com/FairgateLabs/bitvmx-union-bridge-contracts/blob/b656e8c68a46e57c80c7029f9deb9e4b65b60046/src/interfaces/IPausable.sol)

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

