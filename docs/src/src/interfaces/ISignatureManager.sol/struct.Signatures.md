# Signatures
[Git Source](https://github.com/rsksmart/union-bridge-contracts/blob/dd34207db3c68e4260aba3e2d2660c73733e6970/src/interfaces/ISignatureManager.sol)

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

