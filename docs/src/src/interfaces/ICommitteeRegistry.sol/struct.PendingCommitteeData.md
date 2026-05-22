# PendingCommitteeData
[Git Source](https://github.com/rsksmart/union-bridge-contracts/blob/dd34207db3c68e4260aba3e2d2660c73733e6970/src/interfaces/ICommitteeRegistry.sol)

Represents pending data for a member in committee formation

*Contains the aggregated key provided by the member and committee status*


```solidity
struct PendingCommitteeData {
    bytes takeAggregatedKey;
    bytes disputeAggregatedKey;
    bool inCommittee;
    CommunicationData[] communicationData;
}
```

