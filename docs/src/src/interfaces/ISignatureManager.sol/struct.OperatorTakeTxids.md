# OperatorTakeTxids
[Git Source](https://github.com/rsksmart/union-bridge-contracts/blob/dd34207db3c68e4260aba3e2d2660c73733e6970/src/interfaces/ISignatureManager.sol)

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

