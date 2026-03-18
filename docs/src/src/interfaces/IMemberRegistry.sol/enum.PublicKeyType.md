# PublicKeyType
[Git Source](https://github.com/temp-rsk/bitvmx-union-bridge-contracts/blob/ee0115174aa9f16d975ad140f940d23fb1883b23/src/interfaces/IMemberRegistry.sol)

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

