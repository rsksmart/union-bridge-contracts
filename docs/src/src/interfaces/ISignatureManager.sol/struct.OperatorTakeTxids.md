# OperatorTakeTxids
[Git Source](https://github.com/temp-rsk/bitvmx-union-bridge-contracts/blob/0c819fa3fad6abf73f5f2a830cc21b001080582f/src/interfaces/ISignatureManager.sol)

Represents the state of OperatorTake transaction id's for a specific accept peg-in

*Tracks OperatorTake and OperatorWon transaction id's provided by committee members*


```solidity
struct OperatorTakeTxids {
    mapping(address memberAddress => bytes32 operatorTakeTxid) takeTxids;
    mapping(address memberAddress => bytes32 operatorWonTxid) wonTxids;
    uint8 missingHashes;
    uint128 committeeId;
}
```

