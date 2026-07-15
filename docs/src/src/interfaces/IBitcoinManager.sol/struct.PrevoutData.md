# PrevoutData
[Git Source](https://github.com/rsksmart/union-bridge-contracts/blob/b56fdca4d854a3d344854107131d121e04834d63/src/interfaces/IBitcoinManager.sol)

Represents data about a previous transaction output being spent

*Used for signature hash calculation and validation*


```solidity
struct PrevoutData {
    uint64 value;
    bytes scriptPubKey;
}
```

