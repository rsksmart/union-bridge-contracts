# ECDSAPublicKey
[Git Source](https://github.com/temp-rsk/bitvmx-union-bridge-contracts/blob/4c35e62294ee16f56ba26d52283a5d84868fbd84/src/interfaces/ICommitteeRegistry.sol)

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

