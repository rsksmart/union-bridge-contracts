# OperatorTakeTxids
[Git Source](https://github.com/temp-rsk/bitvmx-union-bridge-contracts/blob/71daf3bfeba3a077e1d33188a46c6e2cfea30519/src/interfaces/ISignatureManager.sol)

Represents the state of OperatorTake transaction id's for a specific accept peg-in

*Tracks OperatorTake transaction id's provided by committee members*


```solidity
struct OperatorTakeTxids {
    mapping(address memberAddress => bytes32 operatorTakeTxid) txids;
    uint8 missingHashes;
    uint128 committeeId;
}
```

