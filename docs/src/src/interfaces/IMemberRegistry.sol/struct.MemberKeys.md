# MemberKeys
[Git Source](https://github.com/temp-rsk/bitvmx-union-bridge-contracts/blob/bd6b4a28bf5973e554d9b7a237190a44cdd46b38/src/interfaces/IMemberRegistry.sol)

Member public keys structure for members

*Contains different key types for different purposes*


```solidity
struct MemberKeys {
    CompactPubKey takePubKey;
    CompactPubKey disputePubKey;
    RSAPublicKey communicationPubKey;
}
```

