# BtcTxOut
[Git Source](https://github.com/temp-rsk/bitvmx-union-bridge-contracts/blob/13960dd321557c932048de4fc7353af5ceae0b8d/src/interfaces/IBitcoinManager.sol)

Represents a Bitcoin transaction output that creates a new UTXO

*This struct follows Bitcoin's transaction output format, see: https://learnmeabitcoin.com/technical/transaction/#structure-inputs-txid*

*All multi-byte fields are stored in little-endian format (Bitcoin's native format)*


```solidity
struct BtcTxOut {
    uint64 amount;
    bytes scriptPubKey;
}
```

