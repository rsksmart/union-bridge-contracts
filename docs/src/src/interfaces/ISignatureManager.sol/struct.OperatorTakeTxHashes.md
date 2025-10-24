# OperatorTakeTxHashes
[Git Source](https://github.com/FairgateLabs/bitvmx-union-bridge-contracts/blob/3db9056f26f2b3b61c05819d9eb725e59c32f233/src/interfaces/ISignatureManager.sol)

Represents the state of OperatorTake transaction hashes for a specific accept peg-in

*Tracks OperatorTake transaction hashes provided by committee members*


```solidity
struct OperatorTakeTxHashes {
    mapping(address memberAddress => bytes32 operatorTakeTxHash) txHashes;
    uint8 missingHashes;
    uint128 committeeId;
}
```

