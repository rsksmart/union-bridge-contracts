# PegStatus
[Git Source](https://github.com/temp-rsk/bitvmx-union-bridge-contracts/blob/ee0115174aa9f16d975ad140f940d23fb1883b23/src/interfaces/IPegCommonTypes.sol)

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

