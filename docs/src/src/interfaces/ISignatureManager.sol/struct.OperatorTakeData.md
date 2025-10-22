# OperatorTakeData
[Git Source](https://github.com/FairgateLabs/bitvmx-union-bridge-contracts/blob/d1d7e57632b0c5f559c5c50994a17b0f4b09c742/src/interfaces/ISignatureManager.sol)

Represents OperatorTake transaction data for a committee member

*Used for OperatorTake operations (advance funds to the user)*


```solidity
struct OperatorTakeData {
    bytes32 txHash;
    address memberAddress;
}
```

