# CompactPubKey
[Git Source](https://github.com/rsksmart/union-bridge-contracts/blob/dd34207db3c68e4260aba3e2d2660c73733e6970/src/interfaces/IMemberRegistry.sol)

Compressed Bitcoin public key with parity prefix


```solidity
struct CompactPubKey {
    bytes1 parity;
    bytes32 xOnly;
}
```

