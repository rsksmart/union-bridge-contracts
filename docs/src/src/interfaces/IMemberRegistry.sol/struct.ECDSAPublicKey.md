# ECDSAPublicKey
[Git Source](https://github.com/temp-rsk/bitvmx-union-bridge-contracts/blob/ee0115174aa9f16d975ad140f940d23fb1883b23/src/interfaces/IMemberRegistry.sol)

Represents the data needed for ECDSA public key registration

*Includes the public key coordinates and ECDSA signature for verification*


```solidity
struct ECDSAPublicKey {
    bytes32 publicKeyX;
    bytes32 publicKeyY;
    uint8 v;
    bytes32 r;
    bytes32 s;
}
```

