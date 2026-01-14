# BtcTxOut
[Git Source](https://github.com/temp-rsk/bitvmx-union-bridge-contracts/blob/0c819fa3fad6abf73f5f2a830cc21b001080582f/src/interfaces/IBitcoinManager.sol)

Represents a Bitcoin transaction output that creates a new UTXO

*This struct follows Bitcoin's transaction output format, see: https://learnmeabitcoin.com/technical/transaction/#structure-inputs-txid*

*All multi-byte fields are stored in little-endian format (Bitcoin's native format)*


```solidity
struct BtcTxOut {
    uint64 amount;
    bytes scriptPubKey;
}
```

