# MemberKeys
[Git Source](https://github.com/rsksmart/union-bridge-contracts/blob/68c14faa89612dfba1b7e9abf29455625661476f/src/interfaces/ICommitteeRegistry.sol)

Member public keys structure for members

*Contains different key types for different purposes*


```solidity
struct MemberKeys {
    bytes32 takePubKey;
    bytes32 covenantPubKey;
    RSAPublicKey communicationPubKey;
}
```

