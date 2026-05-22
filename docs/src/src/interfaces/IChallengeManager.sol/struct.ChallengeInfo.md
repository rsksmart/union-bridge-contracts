# ChallengeInfo
[Git Source](https://github.com/rsksmart/union-bridge-contracts/blob/dd34207db3c68e4260aba3e2d2660c73733e6970/src/interfaces/IChallengeManager.sol)

Information stored during challenge processing

*Contains data needed for challenge transaction validation*


```solidity
struct ChallengeInfo {
    bytes32 challengeTxid;
    bytes32 revealTxid;
}
```

