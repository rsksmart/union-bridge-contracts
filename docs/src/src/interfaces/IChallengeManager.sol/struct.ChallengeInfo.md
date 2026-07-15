# ChallengeInfo
[Git Source](https://github.com/rsksmart/union-bridge-contracts/blob/6c85aeb17a23ee9d675a92f8655a551ecca7b4c9/src/interfaces/IChallengeManager.sol)

Information stored during challenge processing

*Contains data needed for challenge transaction validation*


```solidity
struct ChallengeInfo {
    bytes32 challengeTxid;
    bytes32 revealTxid;
}
```

