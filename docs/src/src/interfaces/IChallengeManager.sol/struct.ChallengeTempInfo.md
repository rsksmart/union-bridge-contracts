# ChallengeTempInfo
[Git Source](https://github.com/temp-rsk/bitvmx-union-bridge-contracts/blob/6a9ea8ca3ca82c82894d3db0e338e4bf6bb46de8/src/interfaces/IChallengeManager.sol)

Temporary information stored during challenge processing

*Contains data needed for challenge transaction validation*


```solidity
struct ChallengeTempInfo {
    bytes32 challengeTxid;
    bytes32 revealTxid;
}
```

