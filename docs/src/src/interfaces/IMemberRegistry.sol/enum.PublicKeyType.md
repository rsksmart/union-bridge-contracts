# PublicKeyType
[Git Source](https://github.com/rsksmart/union-bridge-contracts/blob/cf5421e1f47ca597147a56a1404f8189f6c70b20/src/interfaces/IMemberRegistry.sol)

Represents the different types of public keys a member can register

*Each key type serves a specific purpose in the committee operations*


```solidity
enum PublicKeyType {
    TAKE,
    DISPUTE,
    COMMUNICATION,
    LENGTH
}
```

