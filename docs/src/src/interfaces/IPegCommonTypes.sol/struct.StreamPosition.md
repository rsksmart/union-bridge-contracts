# StreamPosition
[Git Source](https://github.com/rsksmart/union-bridge-contracts/blob/cf5421e1f47ca597147a56a1404f8189f6c70b20/src/interfaces/IPegCommonTypes.sol)

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

