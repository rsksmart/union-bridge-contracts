# SignatureData
[Git Source](https://github.com/temp-rsk/bitvmx-union-bridge-contracts/blob/835a0374fad05fe95d66ed5d56f02d5826093237/src/interfaces/ISignatureManager.sol)

Represents signature data for a committee member

*Contains the member's public key, signature, and nonce for multi-signature operations*


```solidity
struct SignatureData {
    bytes32 signature;
    bytes nonce;
}
```

