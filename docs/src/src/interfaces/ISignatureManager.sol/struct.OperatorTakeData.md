# OperatorTakeData
[Git Source](https://github.com/FairgateLabs/bitvmx-union-bridge-contracts/blob/b750ea532307d08987643fe249271c69c1bee159/src/interfaces/ISignatureManager.sol)

Represents OperatorTake transaction data for a committee member

*Used for OperatorTake operations (advance funds to the user)*


```solidity
struct OperatorTakeData {
    bytes32 txHash;
    address memberAddress;
}
```

