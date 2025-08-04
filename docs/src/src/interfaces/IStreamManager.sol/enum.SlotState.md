# SlotState
[Git Source](https://github.com/FairgateLabs/bitvmx-union-bridge-contracts/blob/b41d024ed73655cc3c392a6c92b6259ef625d19d/src/interfaces/IStreamManager.sol)

Represents the current state of a slot in the stream system

*Tracks the progression of funds through the slot lifecycle*


```solidity
enum SlotState {
    RESERVED,
    FILLED,
    LOCKED,
    ADVANCED,
    COMPLETED,
    BLOCKED
}
```

