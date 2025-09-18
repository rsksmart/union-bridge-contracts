# RSAPublicKey
[Git Source](https://github.com/FairgateLabs/bitvmx-union-bridge-contracts/blob/b91181b0a4bd785ef0099b4b80f38101dfa816d0/src/interfaces/ICommitteeRegistry.sol)

Represents RSA public key for communication

*Contains DER-encoded RSA public key*

*We use a fixed bytes32 array for gas efficiency*


```solidity
struct RSAPublicKey {
    bytes32[RSA_PUBLIC_KEY_CHUNKS] rsaPublicKey;
}
```

