# OperatorTakeTxHashes
[Git Source](https://github.com/FairgateLabs/bitvmx-union-bridge-contracts/blob/8e06478fcc29439a812dd6c68981ff5bb04b9543/src/interfaces/ISignatureManager.sol)

Represents the state of OperatorTake transaction hashes for a specific accept peg-in

*Tracks OperatorTake transaction hashes provided by committee members*


```solidity
struct OperatorTakeTxHashes {
    mapping(address memberAddress => bytes32 operatorTakeTxHash) txHashes;
    uint8 missingHashes;
    uint128 committeeId;
}
```

