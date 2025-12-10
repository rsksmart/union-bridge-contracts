# StreamPosition
[Git Source](https://github.com/temp-rsk/bitvmx-union-bridge-contracts/blob/2c7f90ba21d83a98b646123c60d27a00fe0644fd/src/interfaces/IPegManager.sol)

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

