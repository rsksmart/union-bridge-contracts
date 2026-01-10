# PendingCommitteeStatus
[Git Source](https://github.com/temp-rsk/bitvmx-union-bridge-contracts/blob/71daf3bfeba3a077e1d33188a46c6e2cfea30519/src/interfaces/ICommitteeRegistry.sol)

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

