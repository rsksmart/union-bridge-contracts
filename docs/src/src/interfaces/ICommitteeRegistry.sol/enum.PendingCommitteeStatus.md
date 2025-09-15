# PendingCommitteeStatus
[Git Source](https://github.com/FairgateLabs/bitvmx-union-bridge-contracts/blob/71a497b0c34417fb9b1a1c1fb548ecdb459d7d61/src/interfaces/ICommitteeRegistry.sol)

Represents the status of a pending committee formation

*Used to track the success or failure reasons of committee creation*


```solidity
enum PendingCommitteeStatus {
    SUCCESS,
    NOT_ENOUGH_MEMBERS,
    NOT_ENOUGH_OPERATORS,
    NOT_ENOUGH_WATCHTOWERS
}
```

