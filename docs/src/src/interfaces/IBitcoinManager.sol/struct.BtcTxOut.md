# BtcTxOut
[Git Source](https://github.com/FairgateLabs/bitvmx-union-bridge-contracts/blob/0b531d846dee21847f46b6304e71a6006a2ef7c3/src/interfaces/IBitcoinManager.sol)

Represents a Bitcoin transaction output that creates a new UTXO

*This struct follows Bitcoin's transaction output format, see: https://learnmeabitcoin.com/technical/transaction/#structure-inputs-txid*

*All multi-byte fields are stored in little-endian format (Bitcoin's native format)*


```solidity
struct BtcTxOut {
    uint64 amount;
    bytes scriptPubKey;
}
```

