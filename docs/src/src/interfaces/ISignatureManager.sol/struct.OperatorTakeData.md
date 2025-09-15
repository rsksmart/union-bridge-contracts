# OperatorTakeData
[Git Source](https://github.com/FairgateLabs/bitvmx-union-bridge-contracts/blob/71a497b0c34417fb9b1a1c1fb548ecdb459d7d61/src/interfaces/ISignatureManager.sol)

Represents OperatorTake transaction data for a committee member

*Used for OperatorTake operations (advance funds to the user)*


```solidity
struct OperatorTakeData {
    bytes32 txHash;
    address memberAddress;
}
```

