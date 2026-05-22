# RSAPublicKey
[Git Source](https://github.com/rsksmart/union-bridge-contracts/blob/68c14faa89612dfba1b7e9abf29455625661476f/src/interfaces/ICommitteeRegistry.sol)

Represents RSA public key for communication

*Contains DER-encoded RSA public key*

*We use a fixed bytes32 array for gas efficiency*


```solidity
struct RSAPublicKey {
    bytes32[RSA_PUBLIC_KEY_CHUNKS] rsaPublicKey;
}
```

