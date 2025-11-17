# OperatorTakeTxids
[Git Source](https://github.com/FairgateLabs/bitvmx-union-bridge-contracts/blob/b656e8c68a46e57c80c7029f9deb9e4b65b60046/src/interfaces/ISignatureManager.sol)

Represents the state of OperatorTake transaction id's for a specific accept peg-in

*Tracks OperatorTake transaction id's provided by committee members*


```solidity
struct OperatorTakeTxids {
    mapping(address memberAddress => bytes32 operatorTakeTxid) txids;
    uint8 missingHashes;
    uint128 committeeId;
}
```

