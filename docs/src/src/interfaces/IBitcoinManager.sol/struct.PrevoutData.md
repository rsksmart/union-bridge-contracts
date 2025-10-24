# PrevoutData
[Git Source](https://github.com/FairgateLabs/bitvmx-union-bridge-contracts/blob/3db9056f26f2b3b61c05819d9eb725e59c32f233/src/interfaces/IBitcoinManager.sol)

Represents data about a previous transaction output being spent

*Used for signature hash calculation and validation*


```solidity
struct PrevoutData {
    uint64 value;
    bytes scriptPubKey;
}
```

