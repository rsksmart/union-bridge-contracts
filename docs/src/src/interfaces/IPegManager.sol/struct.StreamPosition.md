# StreamPosition
[Git Source](https://github.com/FairgateLabs/bitvmx-union-bridge-contracts/blob/71a497b0c34417fb9b1a1c1fb548ecdb459d7d61/src/interfaces/IPegManager.sol)

Represents the position of funds within the stream and packet system

*Tracks where funds are located in the hierarchical stream/packet/slot structure*


```solidity
struct StreamPosition {
    uint64 streamId;
    uint64 packetNumber;
    uint64 slotId;
    PegStatus pegStatus;
}
```

