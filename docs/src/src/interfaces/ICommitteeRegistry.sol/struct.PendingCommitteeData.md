# PendingCommitteeData
[Git Source](https://github.com/temp-rsk/bitvmx-union-bridge-contracts/blob/835a0374fad05fe95d66ed5d56f02d5826093237/src/interfaces/ICommitteeRegistry.sol)

Represents pending data for a member in committee formation

*Contains the aggregated key provided by the member and committee status*


```solidity
struct PendingCommitteeData {
    bytes aggregatedKey;
    bool inCommittee;
    CommunicationData[] communicationData;
}
```

