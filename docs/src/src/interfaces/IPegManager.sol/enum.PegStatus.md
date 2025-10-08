# PegStatus
[Git Source](https://github.com/FairgateLabs/bitvmx-union-bridge-contracts/blob/0b531d846dee21847f46b6304e71a6006a2ef7c3/src/interfaces/IPegManager.sol)

Represents the current status of a peg-in or peg-out operation

*Tracks the progression of funds through the bridge system*


```solidity
enum PegStatus {
    NOT_REGISTERED,
    REGISTERED,
    ACCEPTED,
    USER_TAKE,
    OPERATOR_TAKE,
    OPERATOR_WON,
    COMPLETED,
    LENGTH
}
```

