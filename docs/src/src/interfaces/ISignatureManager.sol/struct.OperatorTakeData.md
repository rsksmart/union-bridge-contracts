# OperatorTakeData
[Git Source](https://github.com/temp-rsk/bitvmx-union-bridge-contracts/blob/835a0374fad05fe95d66ed5d56f02d5826093237/src/interfaces/ISignatureManager.sol)

Represents OperatorTake transaction data for a committee member

*Used for OperatorTake operations (advance funds to the user)*


```solidity
struct OperatorTakeData {
    bytes32 takeTxid;
    bytes32 wonTxid;
    address memberAddress;
}
```

