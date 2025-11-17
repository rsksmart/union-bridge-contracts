# PrevoutData
[Git Source](https://github.com/FairgateLabs/bitvmx-union-bridge-contracts/blob/b656e8c68a46e57c80c7029f9deb9e4b65b60046/src/interfaces/IBitcoinManager.sol)

Represents data about a previous transaction output being spent

*Used for signature hash calculation and validation*


```solidity
struct PrevoutData {
    uint64 value;
    bytes scriptPubKey;
}
```

