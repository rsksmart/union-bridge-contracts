# UTXO
[Git Source](https://github.com/FairgateLabs/bitvmx-union-bridge-contracts/blob/3db9056f26f2b3b61c05819d9eb725e59c32f233/src/interfaces/ICommitteeRegistry.sol)

Represents a Bitcoin UTXO used for committee member funding


```solidity
struct UTXO {
    bytes32 txid;
    uint32 outputIndex;
    uint64 amount;
}
```

