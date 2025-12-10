# UTXO
[Git Source](https://github.com/temp-rsk/bitvmx-union-bridge-contracts/blob/4c35e62294ee16f56ba26d52283a5d84868fbd84/src/interfaces/ICommitteeRegistry.sol)

Represents a Bitcoin UTXO used for committee member funding


```solidity
struct UTXO {
    bytes32 txid;
    uint32 outputIndex;
    uint64 amount;
}
```

