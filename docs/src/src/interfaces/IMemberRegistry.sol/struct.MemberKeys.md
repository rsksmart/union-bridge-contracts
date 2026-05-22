# MemberKeys
[Git Source](https://github.com/rsksmart/union-bridge-contracts/blob/dd34207db3c68e4260aba3e2d2660c73733e6970/src/interfaces/IMemberRegistry.sol)

Member public keys structure for members

*Contains different key types for different purposes*


```solidity
struct MemberKeys {
    CompactPubKey takePubKey;
    CompactPubKey disputePubKey;
    RSAPublicKey communicationPubKey;
}
```

