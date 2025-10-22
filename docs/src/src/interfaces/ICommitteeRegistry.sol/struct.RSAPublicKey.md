# RSAPublicKey
[Git Source](https://github.com/FairgateLabs/bitvmx-union-bridge-contracts/blob/d1d7e57632b0c5f559c5c50994a17b0f4b09c742/src/interfaces/ICommitteeRegistry.sol)

Represents RSA public key for communication

*Contains DER-encoded RSA public key*

*We use a fixed bytes32 array for gas efficiency*


```solidity
struct RSAPublicKey {
    bytes32[RSA_PUBLIC_KEY_CHUNKS] rsaPublicKey;
}
```

