# ECDSAPublicKey
[Git Source](https://github.com/temp-rsk/bitvmx-union-bridge-contracts/blob/bd6b4a28bf5973e554d9b7a237190a44cdd46b38/src/interfaces/IMemberRegistry.sol)

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

