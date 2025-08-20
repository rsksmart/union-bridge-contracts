# UTXO
[Git Source](https://github.com/FairgateLabs/bitvmx-union-bridge-contracts/blob/8e06478fcc29439a812dd6c68981ff5bb04b9543/src/interfaces/ICommitteeRegistry.sol)

Represents a Bitcoin UTXO used for committee member funding


```solidity
struct UTXO {
    bytes32 txid;
    uint32 outputIndex;
    uint64 amount;
}
```

