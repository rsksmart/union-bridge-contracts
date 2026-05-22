# OperatorTakeInfo
[Git Source](https://github.com/rsksmart/union-bridge-contracts/blob/cf5421e1f47ca597147a56a1404f8189f6c70b20/src/interfaces/IOperatorTakeManager.sol)

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

