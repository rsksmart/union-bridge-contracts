# BtcTxOut
[Git Source](https://github.com/rsksmart/union-bridge-contracts/blob/cf5421e1f47ca597147a56a1404f8189f6c70b20/src/interfaces/IBitcoinManager.sol)

Represents a Bitcoin transaction output that creates a new UTXO

*This struct follows Bitcoin's transaction output format, see: https://learnmeabitcoin.com/technical/transaction/#structure-inputs-txid*

*All multi-byte fields are stored in little-endian format (Bitcoin's native format)*


```solidity
struct BtcTxOut {
    uint64 amount;
    bytes scriptPubKey;
}
```

