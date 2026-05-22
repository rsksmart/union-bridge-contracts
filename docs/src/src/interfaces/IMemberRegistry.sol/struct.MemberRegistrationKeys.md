# MemberRegistrationKeys
[Git Source](https://github.com/rsksmart/union-bridge-contracts/blob/dd34207db3c68e4260aba3e2d2660c73733e6970/src/interfaces/IMemberRegistry.sol)

Member public key registration structure

*Contains mixed key types for registration*


```solidity
struct MemberRegistrationKeys {
    ECDSAPublicKey takeKey;
    ECDSAPublicKey disputeKey;
    RSAPublicKey communicationKey;
}
```

