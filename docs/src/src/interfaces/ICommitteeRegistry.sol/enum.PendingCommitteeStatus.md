# PendingCommitteeStatus
[Git Source](https://github.com/temp-rsk/bitvmx-union-bridge-contracts/blob/4c35e62294ee16f56ba26d52283a5d84868fbd84/src/interfaces/ICommitteeRegistry.sol)

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

