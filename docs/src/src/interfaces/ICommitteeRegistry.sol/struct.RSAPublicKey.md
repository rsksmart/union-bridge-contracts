# RSAPublicKey
[Git Source](https://github.com/temp-rsk/bitvmx-union-bridge-contracts/blob/aa0c5b500b0a03f68164877ee0ab01eebfbdfa68/src/interfaces/ICommitteeRegistry.sol)

Represents RSA public key for communication

*Contains DER-encoded RSA public key*

*We use a fixed bytes32 array for gas efficiency*


```solidity
struct RSAPublicKey {
    bytes32[RSA_PUBLIC_KEY_CHUNKS] rsaPublicKey;
}
```

