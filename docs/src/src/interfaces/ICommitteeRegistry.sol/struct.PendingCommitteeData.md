# PendingCommitteeData
[Git Source](https://github.com/rsksmart/union-bridge-contracts/blob/6c85aeb17a23ee9d675a92f8655a551ecca7b4c9/src/interfaces/ICommitteeRegistry.sol)

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

