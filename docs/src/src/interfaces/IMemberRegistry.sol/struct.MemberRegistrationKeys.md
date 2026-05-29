# MemberRegistrationKeys
[Git Source](https://github.com/rsksmart/union-bridge-contracts/blob/cf5421e1f47ca597147a56a1404f8189f6c70b20/src/interfaces/IMemberRegistry.sol)

Member public key registration structure

*Contains mixed key types for registration*


```solidity
struct MemberRegistrationKeys {
    ECDSAPublicKey takeKey;
    ECDSAPublicKey disputeKey;
    RSAPublicKey communicationKey;
}
```

