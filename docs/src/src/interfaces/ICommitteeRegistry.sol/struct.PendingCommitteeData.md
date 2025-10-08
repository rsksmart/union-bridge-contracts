# PendingCommitteeData
[Git Source](https://github.com/FairgateLabs/bitvmx-union-bridge-contracts/blob/0b531d846dee21847f46b6304e71a6006a2ef7c3/src/interfaces/ICommitteeRegistry.sol)

Represents pending data for a member in committee formation

*Contains the aggregated key provided by the member and committee status*


```solidity
struct PendingCommitteeData {
    bytes aggregatedKey;
    bool inCommittee;
    CommunicationData[] communicationData;
}
```

