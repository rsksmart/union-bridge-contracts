# Committee
[Git Source](https://github.com/FairgateLabs/bitvmx-union-bridge-contracts/blob/b41d024ed73655cc3c392a6c92b6259ef625d19d/src/interfaces/ICommitteeRegistry.sol)

Represents a complete committee with aggregated key and members

*Contains all information needed for committee operations*


```solidity
struct Committee {
    bytes32 aggregatedKey;
    CommitteeMember[] members;
    address leaderAddress;
    uint256 operatorTakeIndex;
}
```

