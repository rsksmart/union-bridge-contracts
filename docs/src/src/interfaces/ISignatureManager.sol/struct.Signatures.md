# Signatures
[Git Source](https://github.com/temp-rsk/bitvmx-union-bridge-contracts/blob/2c7f90ba21d83a98b646123c60d27a00fe0644fd/src/interfaces/ISignatureManager.sol)

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

