# PendingCommitteeStatus
[Git Source](https://github.com/FairgateLabs/bitvmx-union-bridge-contracts/blob/b750ea532307d08987643fe249271c69c1bee159/src/interfaces/ICommitteeRegistry.sol)

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

