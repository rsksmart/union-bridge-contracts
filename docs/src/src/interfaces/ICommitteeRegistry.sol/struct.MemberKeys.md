# MemberKeys
[Git Source](https://github.com/temp-rsk/bitvmx-union-bridge-contracts/blob/6a9ea8ca3ca82c82894d3db0e338e4bf6bb46de8/src/interfaces/ICommitteeRegistry.sol)

Member public keys structure for members

*Contains different key types for different purposes*


```solidity
struct MemberKeys {
    bytes32 takePubKey;
    bytes32 covenantPubKey;
    RSAPublicKey communicationPubKey;
}
```

