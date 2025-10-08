# SlotState
[Git Source](https://github.com/FairgateLabs/bitvmx-union-bridge-contracts/blob/5935b1ba9b5693ff58c693caac2763a4b158c822/src/interfaces/IStreamManager.sol)

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

