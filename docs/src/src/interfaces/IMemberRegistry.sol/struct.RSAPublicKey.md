# RSAPublicKey
[Git Source](https://github.com/rsksmart/union-bridge-contracts/blob/cf5421e1f47ca597147a56a1404f8189f6c70b20/src/interfaces/IMemberRegistry.sol)

Represents RSA public key for communication

*Contains DER-encoded RSA public key*

*We use a fixed bytes32 array for gas efficiency*


```solidity
struct RSAPublicKey {
    bytes32[RSA_PUBLIC_KEY_CHUNKS] rsaPublicKey;
}
```

