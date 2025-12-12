# PegStatus
[Git Source](https://github.com/temp-rsk/bitvmx-union-bridge-contracts/blob/13960dd321557c932048de4fc7353af5ceae0b8d/src/interfaces/IPegCommonTypes.sol)

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

