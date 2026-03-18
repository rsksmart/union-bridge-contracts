# PendingCommitteeData
[Git Source](https://github.com/temp-rsk/bitvmx-union-bridge-contracts/blob/ee0115174aa9f16d975ad140f940d23fb1883b23/src/interfaces/ICommitteeRegistry.sol)

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

