# StreamPosition
[Git Source](https://github.com/rsksmart/union-bridge-contracts/blob/6c85aeb17a23ee9d675a92f8655a551ecca7b4c9/src/interfaces/IPegCommonTypes.sol)

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

