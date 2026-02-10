# SlotState
[Git Source](https://github.com/temp-rsk/bitvmx-union-bridge-contracts/blob/6a9ea8ca3ca82c82894d3db0e338e4bf6bb46de8/src/interfaces/IStreamManager.sol)

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

