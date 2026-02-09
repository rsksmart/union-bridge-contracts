# ChallengeTempInfo
[Git Source](https://github.com/temp-rsk/bitvmx-union-bridge-contracts/blob/835a0374fad05fe95d66ed5d56f02d5826093237/src/interfaces/IChallengeManager.sol)

Temporary information stored during challenge processing

*Contains data needed for challenge transaction validation*


```solidity
struct ChallengeTempInfo {
    bytes32 challengeTxid;
    bytes32 revealTxid;
}
```

