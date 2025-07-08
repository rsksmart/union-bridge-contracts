# PublicKeyRegistration
[Git Source](https://github.com/FairgateLabs/bitvmx-union-bridge-contracts/blob/88ae00b3e8fb636de955be6f15b3c84ce2cc3729/src/interfaces/ICommitteeRegistry.sol)

Represents the data needed for a public key registration

*Includes the public key coordinates and ECDSA signature for verification*


```solidity
struct PublicKeyRegistration {
    bytes32 publicKeyX;
    bytes32 publicKeyY;
    uint8 v;
    bytes32 r;
    bytes32 s;
}
```

