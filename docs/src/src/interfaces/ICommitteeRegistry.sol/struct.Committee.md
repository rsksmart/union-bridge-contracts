# Committee
[Git Source](https://github.com/rsksmart/union-bridge-contracts/blob/68c14faa89612dfba1b7e9abf29455625661476f/src/interfaces/ICommitteeRegistry.sol)

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

