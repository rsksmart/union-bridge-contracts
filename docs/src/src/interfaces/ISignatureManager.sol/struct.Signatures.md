# Signatures
[Git Source](https://github.com/temp-rsk/bitvmx-union-bridge-contracts/blob/aa0c5b500b0a03f68164877ee0ab01eebfbdfa68/src/interfaces/ISignatureManager.sol)

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

