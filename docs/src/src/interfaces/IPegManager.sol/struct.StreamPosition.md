# StreamPosition
[Git Source](https://github.com/FairgateLabs/bitvmx-union-bridge-contracts/blob/b750ea532307d08987643fe249271c69c1bee159/src/interfaces/IPegManager.sol)

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

