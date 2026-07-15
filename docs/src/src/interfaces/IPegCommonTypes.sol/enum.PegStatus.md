# PegStatus
[Git Source](https://github.com/rsksmart/union-bridge-contracts/blob/b56fdca4d854a3d344854107131d121e04834d63/src/interfaces/IPegCommonTypes.sol)

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

