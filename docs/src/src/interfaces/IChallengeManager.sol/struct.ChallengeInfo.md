# ChallengeInfo
[Git Source](https://github.com/rsksmart/union-bridge-contracts/blob/cf5421e1f47ca597147a56a1404f8189f6c70b20/src/interfaces/IChallengeManager.sol)

Information stored during challenge processing

*Contains data needed for challenge transaction validation*


```solidity
struct ChallengeInfo {
    bytes32 challengeTxid;
    bytes32 revealTxid;
}
```

