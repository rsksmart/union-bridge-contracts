# SlotState
[Git Source](https://github.com/FairgateLabs/bitvmx-union-bridge-contracts/blob/9f14e34a8636f5a1e820830e7bebc3a177006c7a/src/interfaces/IStreamManager.sol)

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

