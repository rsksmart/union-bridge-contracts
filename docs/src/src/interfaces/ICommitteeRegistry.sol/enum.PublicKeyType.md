# PublicKeyType
[Git Source](https://github.com/rsksmart/union-bridge-contracts/blob/b56fdca4d854a3d344854107131d121e04834d63/src/interfaces/ICommitteeRegistry.sol)

Represents the different types of public keys a member can register

*Each key type serves a specific purpose in the committee operations*


```solidity
enum PublicKeyType {
    TAKE,
    COVENANT,
    COMMUNICATION,
    LENGTH
}
```

