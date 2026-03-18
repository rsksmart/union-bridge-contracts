# MemberKeys
[Git Source](https://github.com/temp-rsk/bitvmx-union-bridge-contracts/blob/ee0115174aa9f16d975ad140f940d23fb1883b23/src/interfaces/IMemberRegistry.sol)

Member public keys structure for members

*Contains different key types for different purposes*


```solidity
struct MemberKeys {
    CompactPubKey takePubKey;
    CompactPubKey disputePubKey;
    RSAPublicKey communicationPubKey;
}
```

