# Committee
[Git Source](https://github.com/temp-rsk/bitvmx-union-bridge-contracts/blob/bd6b4a28bf5973e554d9b7a237190a44cdd46b38/src/interfaces/ICommitteeRegistry.sol)

Represents a complete committee with aggregated key and members

*Contains all information needed for committee operations*


```solidity
struct Committee {
    bytes takeAggregatedKey;
    bytes disputeAggregatedKey;
    CommitteeMember[] members;
    address leaderAddress;
    uint256 operatorTakeIndex;
    uint256 createdAt;
    uint16 missingData;
    uint16 missingCommunicationData;
    bool isPending;
    uint64 streamId;
    UTXO[] fundingUTXOs;
}
```

