# MemberRegistrationKeys
[Git Source](https://github.com/FairgateLabs/bitvmx-union-bridge-contracts/blob/8e06478fcc29439a812dd6c68981ff5bb04b9543/src/interfaces/ICommitteeRegistry.sol)

Member public key registration structure

*Contains mixed key types for registration*


```solidity
struct MemberRegistrationKeys {
    ECDSAPublicKey takeKey;
    ECDSAPublicKey covenantKey;
    RSAPublicKey communicationKey;
}
```

