# Stream
[Git Source](https://github.com/FairgateLabs/bitvmx-union-bridge-contracts/blob/d1d7e57632b0c5f559c5c50994a17b0f4b09c742/src/interfaces/IStreamManager.sol)

Represents a stream that manages funds of a specific denomination

*Each stream handles a specific Bitcoin amount for efficient fund management*


```solidity
struct Stream {
    uint64 streamId;
    uint64 denomination;
    uint64 peginPacketPointer;
    uint64 pegoutPacketPointer;
    uint16 pegoutSlotPointer;
    uint8 peginConfirmations;
    uint8 pegoutConfirmations;
}
```

