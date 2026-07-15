# MemberKeys
[Git Source](https://github.com/rsksmart/union-bridge-contracts/blob/6c85aeb17a23ee9d675a92f8655a551ecca7b4c9/src/interfaces/IMemberRegistry.sol)

Member public keys structure for members

*Contains different key types for different purposes*


```solidity
struct MemberKeys {
    CompactPubKey takePubKey;
    CompactPubKey disputePubKey;
    RSAPublicKey communicationPubKey;
}
```

