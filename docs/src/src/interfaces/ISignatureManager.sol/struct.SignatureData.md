# SignatureData
[Git Source](https://github.com/temp-rsk/bitvmx-union-bridge-contracts/blob/2c7f90ba21d83a98b646123c60d27a00fe0644fd/src/interfaces/ISignatureManager.sol)

Represents signature data for a committee member

*Contains the member's public key, signature, and nonce for multi-signature operations*


```solidity
struct SignatureData {
    bytes32 signature;
    bytes nonce;
}
```

