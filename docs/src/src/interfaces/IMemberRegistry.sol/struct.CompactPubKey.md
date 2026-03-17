# CompactPubKey
[Git Source](https://github.com/temp-rsk/bitvmx-union-bridge-contracts/blob/ee0115174aa9f16d975ad140f940d23fb1883b23/src/interfaces/IMemberRegistry.sol)

Compressed Bitcoin public key with parity prefix


```solidity
struct CompactPubKey {
    bytes1 parity;
    bytes32 xOnly;
}
```

