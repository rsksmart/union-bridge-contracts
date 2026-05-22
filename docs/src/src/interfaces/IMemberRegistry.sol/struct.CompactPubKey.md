# CompactPubKey
[Git Source](https://github.com/rsksmart/union-bridge-contracts/blob/cf5421e1f47ca597147a56a1404f8189f6c70b20/src/interfaces/IMemberRegistry.sol)

Compressed Bitcoin public key with parity prefix


```solidity
struct CompactPubKey {
    bytes1 parity;
    bytes32 xOnly;
}
```

