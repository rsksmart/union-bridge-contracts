# PendingCommittee
[Git Source](https://github.com/FairgateLabs/bitvmx-union-bridge-contracts/blob/88ae00b3e8fb636de955be6f15b3c84ce2cc3729/src/interfaces/ICommitteeRegistry.sol)

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

