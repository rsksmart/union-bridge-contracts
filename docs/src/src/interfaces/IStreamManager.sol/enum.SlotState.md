# SlotState
[Git Source](https://github.com/temp-rsk/bitvmx-union-bridge-contracts/blob/13960dd321557c932048de4fc7353af5ceae0b8d/src/interfaces/IStreamManager.sol)

Represents the current state of a slot in the stream system

*Tracks the progression of funds through the slot lifecycle*


```solidity
enum SlotState {
    RESERVED,
    FILLED,
    LOCKED,
    ADVANCED,
    COMPLETED,
    BLOCKED,
    LENGTH
}
```

