# PublicKeyType
[Git Source](https://github.com/rsksmart/union-bridge-contracts/blob/6c85aeb17a23ee9d675a92f8655a551ecca7b4c9/src/interfaces/IMemberRegistry.sol)

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

