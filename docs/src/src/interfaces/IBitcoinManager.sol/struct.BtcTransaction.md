# BtcTransaction
[Git Source](https://github.com/rsksmart/union-bridge-contracts/blob/68c14faa89612dfba1b7e9abf29455625661476f/src/interfaces/IBitcoinManager.sol)

Represents a complete Bitcoin transaction structure for union bridge operations

*This struct follows Bitcoin's transaction format as defined in BIP-141 and related specifications*

*All multi-byte fields are stored in little-endian format (Bitcoin's native format)*

*The witness data is excluded from this struct as it's not needed for transaction id calculation*

*For more details on Bitcoin transaction structure, see: https://learnmeabitcoin.com/technical/transaction/#structure-inputs-txid*


```solidity
struct BtcTransaction {
    uint32 version;
    BtcTxIn[] inputs;
    BtcTxOut[] outputs;
    uint32 locktime;
}
```

