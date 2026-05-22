# OperatorTakeInfo
[Git Source](https://github.com/temp-rsk/bitvmx-union-bridge-contracts/blob/bd6b4a28bf5973e554d9b7a237190a44cdd46b38/src/interfaces/IOperatorTakeManager.sol)

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

