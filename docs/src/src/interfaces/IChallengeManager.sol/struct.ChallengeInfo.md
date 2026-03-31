# ChallengeInfo
[Git Source](https://github.com/temp-rsk/bitvmx-union-bridge-contracts/blob/bd6b4a28bf5973e554d9b7a237190a44cdd46b38/src/interfaces/IChallengeManager.sol)

Information stored during challenge processing

*Contains data needed for challenge transaction validation*


```solidity
struct ChallengeInfo {
    bytes32 challengeTxid;
    bytes32 revealTxid;
}
```

