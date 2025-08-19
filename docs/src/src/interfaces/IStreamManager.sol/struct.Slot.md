# Slot
[Git Source](https://github.com/FairgateLabs/bitvmx-union-bridge-contracts/blob/b750ea532307d08987643fe249271c69c1bee159/src/interfaces/IStreamManager.sol)

Represents a slot within a packet that can hold funds

*Each slot corresponds to a specific UTXO in the Bitcoin network*


```solidity
struct Slot {
    uint64 slotId;
    SlotState state;
    bytes scriptPubKey;
    bytes32 acceptPeginTx;
    uint64 acceptPeginAmount;
    bytes32 take0Tx;
    bytes32 take1Tx;
}
```

