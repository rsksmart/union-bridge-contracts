# PegStatus
[Git Source](https://github.com/temp-rsk/bitvmx-union-bridge-contracts/blob/0c819fa3fad6abf73f5f2a830cc21b001080582f/src/interfaces/IPegCommonTypes.sol)

Represents the current status of a peg-in or peg-out operation

*Tracks the progression of funds through the bridge system*


```solidity
enum PegStatus {
    NOT_REGISTERED,
    REGISTERED,
    ACCEPTED,
    USER_TAKE,
    OP_SELECTED,
    ADVANCED,
    KICKOFF,
    CHALLENGE,
    REVEALED,
    COMPLETED,
    BLOCKED,
    LENGTH
}
```

