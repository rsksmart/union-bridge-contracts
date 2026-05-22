# ChallengeTempInfo
[Git Source](https://github.com/temp-rsk/bitvmx-union-bridge-contracts/blob/aa0c5b500b0a03f68164877ee0ab01eebfbdfa68/src/interfaces/IChallengeManager.sol)

Temporary information stored during challenge processing

*Contains data needed for challenge transaction validation*


```solidity
struct ChallengeTempInfo {
    bytes32 challengeTxid;
    bytes32 revealTxid;
}
```

