# ECDSAPublicKey
[Git Source](https://github.com/rsksmart/union-bridge-contracts/blob/dd34207db3c68e4260aba3e2d2660c73733e6970/src/interfaces/IMemberRegistry.sol)

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

