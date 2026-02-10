# Signatures
[Git Source](https://github.com/temp-rsk/bitvmx-union-bridge-contracts/blob/6a9ea8ca3ca82c82894d3db0e338e4bf6bb46de8/src/interfaces/ISignatureManager.sol)

Represents the state of signatures for a specific hash

*Tracks partial signatures, missing signatures, and committee information*


```solidity
struct Signatures {
    mapping(address memberAddress => SignatureData) partialSignaturesData;
    uint8 missingSignatures;
    uint8 missingNonces;
    uint128 committeeId;
}
```

