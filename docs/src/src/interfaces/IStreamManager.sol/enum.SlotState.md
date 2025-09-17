# SlotState
[Git Source](https://github.com/FairgateLabs/bitvmx-union-bridge-contracts/blob/71a497b0c34417fb9b1a1c1fb548ecdb459d7d61/src/interfaces/IStreamManager.sol)

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

