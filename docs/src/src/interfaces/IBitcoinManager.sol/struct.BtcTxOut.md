# BtcTxOut
[Git Source](https://github.com/FairgateLabs/bitvmx-union-bridge-contracts/blob/b656e8c68a46e57c80c7029f9deb9e4b65b60046/src/interfaces/IBitcoinManager.sol)

Represents a Bitcoin transaction output that creates a new UTXO

*This struct follows Bitcoin's transaction output format, see: https://learnmeabitcoin.com/technical/transaction/#structure-inputs-txid*

*All multi-byte fields are stored in little-endian format (Bitcoin's native format)*


```solidity
struct BtcTxOut {
    uint64 amount;
    bytes scriptPubKey;
}
```

