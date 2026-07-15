# PegStatus
[Git Source](https://github.com/rsksmart/union-bridge-contracts/blob/6c85aeb17a23ee9d675a92f8655a551ecca7b4c9/src/interfaces/IPegCommonTypes.sol)

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

