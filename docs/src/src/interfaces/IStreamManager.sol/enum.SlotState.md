# SlotState
[Git Source](https://github.com/FairgateLabs/bitvmx-union-bridge-contracts/blob/0b531d846dee21847f46b6304e71a6006a2ef7c3/src/interfaces/IStreamManager.sol)

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

