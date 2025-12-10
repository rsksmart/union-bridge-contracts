# MemberKeys
[Git Source](https://github.com/temp-rsk/bitvmx-union-bridge-contracts/blob/2c7f90ba21d83a98b646123c60d27a00fe0644fd/src/interfaces/ICommitteeRegistry.sol)

Member public keys structure for members

*Contains different key types for different purposes*


```solidity
struct MemberKeys {
    bytes32 takePubKey;
    bytes32 covenantPubKey;
    RSAPublicKey communicationPubKey;
}
```

