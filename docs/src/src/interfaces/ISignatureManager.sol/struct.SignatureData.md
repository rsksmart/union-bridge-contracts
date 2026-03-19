# SignatureData
[Git Source](https://github.com/temp-rsk/bitvmx-union-bridge-contracts/blob/ee0115174aa9f16d975ad140f940d23fb1883b23/src/interfaces/ISignatureManager.sol)

Represents signature data for a committee member

*Contains the member's public key, signature, and nonce for multi-signature operations*


```solidity
struct SignatureData {
    bytes32 signature;
    bytes nonce;
}
```

