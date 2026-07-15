# SignatureData
[Git Source](https://github.com/rsksmart/union-bridge-contracts/blob/b56fdca4d854a3d344854107131d121e04834d63/src/interfaces/ISignatureManager.sol)

Represents signature data for a committee member

*Contains the member's public key, signature, and nonce for multi-signature operations*


```solidity
struct SignatureData {
    bytes32 signature;
    bytes nonce;
}
```

