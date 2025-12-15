# Stream
[Git Source](https://github.com/temp-rsk/bitvmx-union-bridge-contracts/blob/96535706e496364789ce242b18e17052bb6e424e/src/interfaces/IStreamManager.sol)

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

