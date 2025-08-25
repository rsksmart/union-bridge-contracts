# Committee
[Git Source](https://github.com/FairgateLabs/bitvmx-union-bridge-contracts/blob/9f14e34a8636f5a1e820830e7bebc3a177006c7a/src/interfaces/ICommitteeRegistry.sol)

Represents a complete committee with aggregated key and members

*Contains all information needed for committee operations*


```solidity
struct Committee {
    bytes32 aggregatedKey;
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

