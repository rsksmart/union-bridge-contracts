# SignatureData
[Git Source](https://github.com/FairgateLabs/bitvmx-union-bridge-contracts/blob/8e06478fcc29439a812dd6c68981ff5bb04b9543/src/interfaces/ISignatureManager.sol)

Represents signature data for a committee member

*Contains the member's public key, signature, and nonce for multi-signature operations*


```solidity
struct SignatureData {
    bytes32 signature;
    bytes nonce;
}
```

