# OperatorTakeData
[Git Source](https://github.com/FairgateLabs/bitvmx-union-bridge-contracts/blob/88ae00b3e8fb636de955be6f15b3c84ce2cc3729/src/interfaces/ISignatureManager.sol)

Represents OperatorTake transaction data for a committee member

*Used for OperatorTake operations (advance funds to the user)*


```solidity
struct OperatorTakeData {
    bytes32 txHash;
    address memberAddress;
}
```

