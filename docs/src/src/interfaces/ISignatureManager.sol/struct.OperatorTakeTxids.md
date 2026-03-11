# OperatorTakeTxids
[Git Source](https://github.com/temp-rsk/bitvmx-union-bridge-contracts/blob/aa0c5b500b0a03f68164877ee0ab01eebfbdfa68/src/interfaces/ISignatureManager.sol)

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

