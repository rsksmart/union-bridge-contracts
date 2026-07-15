# CompactPubKey
[Git Source](https://github.com/rsksmart/union-bridge-contracts/blob/6c85aeb17a23ee9d675a92f8655a551ecca7b4c9/src/interfaces/IMemberRegistry.sol)

Compressed Bitcoin public key with parity prefix


```solidity
struct CompactPubKey {
    bytes1 parity;
    bytes32 xOnly;
}
```

