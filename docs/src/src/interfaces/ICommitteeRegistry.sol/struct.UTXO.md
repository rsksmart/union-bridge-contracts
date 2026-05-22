# UTXO
[Git Source](https://github.com/rsksmart/union-bridge-contracts/blob/68c14faa89612dfba1b7e9abf29455625661476f/src/interfaces/ICommitteeRegistry.sol)

Represents a Bitcoin UTXO used for committee member funding


```solidity
struct UTXO {
    bytes32 txid;
    uint32 outputIndex;
    uint64 amount;
}
```

