# MemberKeys
[Git Source](https://github.com/FairgateLabs/bitvmx-union-bridge-contracts/blob/9f14e34a8636f5a1e820830e7bebc3a177006c7a/src/interfaces/ICommitteeRegistry.sol)

Member public keys structure for members

*Contains different key types for different purposes*


```solidity
struct MemberKeys {
    bytes32 takePubKey;
    bytes32 covenantPubKey;
    RSAPublicKey communicationPubKey;
}
```

