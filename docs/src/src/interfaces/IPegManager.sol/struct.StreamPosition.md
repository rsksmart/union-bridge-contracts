# StreamPosition
[Git Source](https://github.com/temp-rsk/bitvmx-union-bridge-contracts/blob/71daf3bfeba3a077e1d33188a46c6e2cfea30519/src/interfaces/IPegManager.sol)

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

