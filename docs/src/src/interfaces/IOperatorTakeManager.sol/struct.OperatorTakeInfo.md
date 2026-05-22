# OperatorTakeInfo
[Git Source](https://github.com/rsksmart/union-bridge-contracts/blob/dd34207db3c68e4260aba3e2d2660c73733e6970/src/interfaces/IOperatorTakeManager.sol)

Information for operator take flow (stored in OperatorTakeManager)


```solidity
struct OperatorTakeInfo {
    uint256 operatorTakeUpdatedAt;
    address operatorTakeAddress;
    CompactPubKey operatorTakePubKey;
    CompactPubKey operatorDisputePubKey;
    bytes32 pegoutId;
    int256 advanceFundsBlockNumber;
    bytes32 reimbursementKickoffTxid;
}
```

