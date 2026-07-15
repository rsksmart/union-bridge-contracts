# OperatorTakeTxids
[Git Source](https://github.com/rsksmart/union-bridge-contracts/blob/b56fdca4d854a3d344854107131d121e04834d63/src/interfaces/ISignatureManager.sol)

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

