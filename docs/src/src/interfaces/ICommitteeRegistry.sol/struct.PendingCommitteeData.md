# PendingCommitteeData
[Git Source](https://github.com/temp-rsk/bitvmx-union-bridge-contracts/blob/bd6b4a28bf5973e554d9b7a237190a44cdd46b38/src/interfaces/ICommitteeRegistry.sol)

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

