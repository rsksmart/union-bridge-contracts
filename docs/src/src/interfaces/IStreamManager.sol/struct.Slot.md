# Slot
[Git Source](https://github.com/rsksmart/union-bridge-contracts/blob/68c14faa89612dfba1b7e9abf29455625661476f/src/interfaces/IStreamManager.sol)

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
}
```

