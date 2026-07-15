# ChallengeTempInfo
[Git Source](https://github.com/rsksmart/union-bridge-contracts/blob/b56fdca4d854a3d344854107131d121e04834d63/src/interfaces/IChallengeManager.sol)

Temporary information stored during challenge processing

*Contains data needed for challenge transaction validation*


```solidity
struct ChallengeTempInfo {
    bytes32 challengeTxid;
    bytes32 revealTxid;
}
```

