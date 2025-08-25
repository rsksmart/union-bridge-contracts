# UTXO
[Git Source](https://github.com/FairgateLabs/bitvmx-union-bridge-contracts/blob/9f14e34a8636f5a1e820830e7bebc3a177006c7a/src/interfaces/ICommitteeRegistry.sol)

Represents a Bitcoin UTXO used for committee member funding


```solidity
struct UTXO {
    bytes32 txid;
    uint32 outputIndex;
    uint64 amount;
}
```

