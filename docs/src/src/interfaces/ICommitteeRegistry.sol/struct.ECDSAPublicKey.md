# ECDSAPublicKey
[Git Source](https://github.com/temp-rsk/bitvmx-union-bridge-contracts/blob/aa0c5b500b0a03f68164877ee0ab01eebfbdfa68/src/interfaces/ICommitteeRegistry.sol)

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

