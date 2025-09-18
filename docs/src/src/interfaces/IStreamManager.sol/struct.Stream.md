# Stream
[Git Source](https://github.com/FairgateLabs/bitvmx-union-bridge-contracts/blob/b91181b0a4bd785ef0099b4b80f38101dfa816d0/src/interfaces/IStreamManager.sol)

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

