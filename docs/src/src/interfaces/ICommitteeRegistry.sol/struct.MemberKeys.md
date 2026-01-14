# MemberKeys
[Git Source](https://github.com/temp-rsk/bitvmx-union-bridge-contracts/blob/0c819fa3fad6abf73f5f2a830cc21b001080582f/src/interfaces/ICommitteeRegistry.sol)

Member public keys structure for members

*Contains different key types for different purposes*


```solidity
struct MemberKeys {
    bytes32 takePubKey;
    bytes32 covenantPubKey;
    RSAPublicKey communicationPubKey;
}
```

