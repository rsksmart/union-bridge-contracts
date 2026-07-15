# OperatorTakeInfo
[Git Source](https://github.com/rsksmart/union-bridge-contracts/blob/6c85aeb17a23ee9d675a92f8655a551ecca7b4c9/src/interfaces/IOperatorTakeManager.sol)

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

