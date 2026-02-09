# PrevoutData
[Git Source](https://github.com/temp-rsk/bitvmx-union-bridge-contracts/blob/835a0374fad05fe95d66ed5d56f02d5826093237/src/interfaces/IBitcoinManager.sol)

Represents data about a previous transaction output being spent

*Used for signature hash calculation and validation*


```solidity
struct PrevoutData {
    uint64 value;
    bytes scriptPubKey;
}
```

