# ChallengeTempInfo
[Git Source](https://github.com/rsksmart/union-bridge-contracts/blob/68c14faa89612dfba1b7e9abf29455625661476f/src/interfaces/IChallengeManager.sol)

Temporary information stored during challenge processing

*Contains data needed for challenge transaction validation*


```solidity
struct ChallengeTempInfo {
    bytes32 challengeTxid;
    bytes32 revealTxid;
}
```

