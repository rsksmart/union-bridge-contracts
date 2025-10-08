# MemberRegistrationKeys
[Git Source](https://github.com/FairgateLabs/bitvmx-union-bridge-contracts/blob/5935b1ba9b5693ff58c693caac2763a4b158c822/src/interfaces/ICommitteeRegistry.sol)

Member public key registration structure

*Contains mixed key types for registration*


```solidity
struct MemberRegistrationKeys {
    ECDSAPublicKey takeKey;
    ECDSAPublicKey covenantKey;
    RSAPublicKey communicationKey;
}
```

