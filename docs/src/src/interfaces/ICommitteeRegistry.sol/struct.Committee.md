# Committee
[Git Source](https://github.com/FairgateLabs/bitvmx-union-bridge-contracts/blob/b91181b0a4bd785ef0099b4b80f38101dfa816d0/src/interfaces/ICommitteeRegistry.sol)

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

