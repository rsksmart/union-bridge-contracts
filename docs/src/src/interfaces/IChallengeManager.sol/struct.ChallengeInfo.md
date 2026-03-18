# ChallengeInfo
[Git Source](https://github.com/temp-rsk/bitvmx-union-bridge-contracts/blob/ee0115174aa9f16d975ad140f940d23fb1883b23/src/interfaces/IChallengeManager.sol)

Information stored during challenge processing

*Contains data needed for challenge transaction validation*


```solidity
struct ChallengeInfo {
    bytes32 challengeTxid;
    bytes32 revealTxid;
}
```

