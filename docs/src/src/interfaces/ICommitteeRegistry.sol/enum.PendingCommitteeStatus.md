# PendingCommitteeStatus
[Git Source](https://github.com/FairgateLabs/bitvmx-union-bridge-contracts/blob/d1d7e57632b0c5f559c5c50994a17b0f4b09c742/src/interfaces/ICommitteeRegistry.sol)

Represents the status of a pending committee formation

*Used to track the success or failure reasons of committee creation*


```solidity
enum PendingCommitteeStatus {
    SUCCESS,
    NOT_ENOUGH_MEMBERS,
    NOT_ENOUGH_OPERATORS,
    NOT_ENOUGH_WATCHTOWERS,
    LENGTH
}
```

