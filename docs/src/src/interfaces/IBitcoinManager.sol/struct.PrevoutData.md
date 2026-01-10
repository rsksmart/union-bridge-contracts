# PrevoutData
[Git Source](https://github.com/temp-rsk/bitvmx-union-bridge-contracts/blob/71daf3bfeba3a077e1d33188a46c6e2cfea30519/src/interfaces/IBitcoinManager.sol)

Represents data about a previous transaction output being spent

*Used for signature hash calculation and validation*


```solidity
struct PrevoutData {
    uint64 value;
    bytes scriptPubKey;
}
```

