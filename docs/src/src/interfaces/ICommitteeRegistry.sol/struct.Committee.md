# Committee
[Git Source](https://github.com/temp-rsk/bitvmx-union-bridge-contracts/blob/71daf3bfeba3a077e1d33188a46c6e2cfea30519/src/interfaces/ICommitteeRegistry.sol)

Represents a complete committee with aggregated key and members

*Contains all information needed for committee operations*


```solidity
struct Committee {
    bytes aggregatedKey;
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

