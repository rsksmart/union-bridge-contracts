# PendingCommittee
[Git Source](https://github.com/FairgateLabs/bitvmx-union-bridge-contracts/blob/b41d024ed73655cc3c392a6c92b6259ef625d19d/src/interfaces/ICommitteeRegistry.sol)

Represents a committee that is in the process of being formed

*Used to track committee formation progress and member data collection*


```solidity
struct PendingCommittee {
    Committee committee;
    uint256 createdAt;
    uint16 missingData;
    uint16 missingCommunicationData;
    mapping(address memberAddress => PendingCommitteeData) data;
}
```

