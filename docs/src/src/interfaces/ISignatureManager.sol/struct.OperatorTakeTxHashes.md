# OperatorTakeTxHashes
[Git Source](https://github.com/FairgateLabs/bitvmx-union-bridge-contracts/blob/b91181b0a4bd785ef0099b4b80f38101dfa816d0/src/interfaces/ISignatureManager.sol)

Represents the state of OperatorTake transaction hashes for a specific accept peg-in

*Tracks OperatorTake transaction hashes provided by committee members*


```solidity
struct OperatorTakeTxHashes {
    mapping(address memberAddress => bytes32 operatorTakeTxHash) txHashes;
    uint8 missingHashes;
    uint128 committeeId;
}
```

