# Committee
[Git Source](https://github.com/FairgateLabs/bitvmx-union-bridge-contracts/blob/88ae00b3e8fb636de955be6f15b3c84ce2cc3729/src/interfaces/ICommitteeRegistry.sol)

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

