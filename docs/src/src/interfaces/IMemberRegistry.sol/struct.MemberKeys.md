# MemberKeys
[Git Source](https://github.com/rsksmart/union-bridge-contracts/blob/cf5421e1f47ca597147a56a1404f8189f6c70b20/src/interfaces/IMemberRegistry.sol)

Member public keys structure for members

*Contains different key types for different purposes*


```solidity
struct MemberKeys {
    CompactPubKey takePubKey;
    CompactPubKey disputePubKey;
    RSAPublicKey communicationPubKey;
}
```

