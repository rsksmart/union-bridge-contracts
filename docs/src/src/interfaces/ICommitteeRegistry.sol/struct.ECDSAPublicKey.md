# ECDSAPublicKey
[Git Source](https://github.com/rsksmart/union-bridge-contracts/blob/b56fdca4d854a3d344854107131d121e04834d63/src/interfaces/ICommitteeRegistry.sol)

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

