# OperatorTakeTxHashes
[Git Source](https://github.com/FairgateLabs/bitvmx-union-bridge-contracts/blob/b41d024ed73655cc3c392a6c92b6259ef625d19d/src/interfaces/ISignatureManager.sol)

Represents the state of OperatorTake transaction hashes for a specific accept peg-in

*Tracks OperatorTake transaction hashes provided by committee members*


```solidity
struct OperatorTakeTxHashes {
    mapping(address memberAddress => bytes32 operatorTakeTxHash) txHashes;
    uint8 missingHashes;
    uint256 committeeId;
}
```

