# OperatorTakeTxHashes
[Git Source](https://github.com/FairgateLabs/bitvmx-union-bridge-contracts/blob/0b531d846dee21847f46b6304e71a6006a2ef7c3/src/interfaces/ISignatureManager.sol)

Represents the state of OperatorTake transaction hashes for a specific accept peg-in

*Tracks OperatorTake transaction hashes provided by committee members*


```solidity
struct OperatorTakeTxHashes {
    mapping(address memberAddress => bytes32 operatorTakeTxHash) txHashes;
    uint8 missingHashes;
    uint128 committeeId;
}
```

