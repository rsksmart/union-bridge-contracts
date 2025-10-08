# ECDSAPublicKey
[Git Source](https://github.com/FairgateLabs/bitvmx-union-bridge-contracts/blob/0b531d846dee21847f46b6304e71a6006a2ef7c3/src/interfaces/ICommitteeRegistry.sol)

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

