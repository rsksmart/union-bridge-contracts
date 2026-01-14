# Slot
[Git Source](https://github.com/temp-rsk/bitvmx-union-bridge-contracts/blob/0c819fa3fad6abf73f5f2a830cc21b001080582f/src/interfaces/IStreamManager.sol)

Represents a slot within a packet that can hold funds

*Each slot corresponds to a specific UTXO in the Bitcoin network*


```solidity
struct Slot {
    uint64 slotId;
    SlotState state;
    bytes scriptPubKey;
    bytes32 acceptPeginTx;
    uint64 acceptPeginAmount;
    bytes32 takeTx;
    bytes enablerScriptPubKey;
}
```

