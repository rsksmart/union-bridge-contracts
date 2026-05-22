# PublicKeyType
[Git Source](https://github.com/rsksmart/union-bridge-contracts/blob/dd34207db3c68e4260aba3e2d2660c73733e6970/src/interfaces/IMemberRegistry.sol)

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

