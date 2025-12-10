# Signatures
[Git Source](https://github.com/temp-rsk/bitvmx-union-bridge-contracts/blob/4c35e62294ee16f56ba26d52283a5d84868fbd84/src/interfaces/ISignatureManager.sol)

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

