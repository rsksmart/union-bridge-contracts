# PendingCommitteeData
[Git Source](https://github.com/rsksmart/union-bridge-contracts/blob/cf5421e1f47ca597147a56a1404f8189f6c70b20/src/interfaces/ICommitteeRegistry.sol)

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

