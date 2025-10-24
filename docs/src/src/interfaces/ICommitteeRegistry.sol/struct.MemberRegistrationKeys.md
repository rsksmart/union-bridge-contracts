# MemberRegistrationKeys
[Git Source](https://github.com/FairgateLabs/bitvmx-union-bridge-contracts/blob/3db9056f26f2b3b61c05819d9eb725e59c32f233/src/interfaces/ICommitteeRegistry.sol)

Member public key registration structure

*Contains mixed key types for registration*


```solidity
struct MemberRegistrationKeys {
    ECDSAPublicKey takeKey;
    ECDSAPublicKey covenantKey;
    RSAPublicKey communicationKey;
}
```

