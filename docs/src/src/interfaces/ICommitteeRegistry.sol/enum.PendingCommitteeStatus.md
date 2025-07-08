# PendingCommitteeStatus
[Git Source](https://github.com/FairgateLabs/bitvmx-union-bridge-contracts/blob/88ae00b3e8fb636de955be6f15b3c84ce2cc3729/src/interfaces/ICommitteeRegistry.sol)

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

