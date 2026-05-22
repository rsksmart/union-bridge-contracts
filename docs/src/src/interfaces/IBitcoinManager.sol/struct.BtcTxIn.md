# BtcTxIn
[Git Source](https://github.com/rsksmart/union-bridge-contracts/blob/68c14faa89612dfba1b7e9abf29455625661476f/src/interfaces/IBitcoinManager.sol)

Represents a Bitcoin transaction input that references a previous UTXO

*This struct follows Bitcoin's transaction input format as defined in BIP-141*

*All multi-byte fields are stored in little-endian format (Bitcoin's native format)*

*For more details on Bitcoin transaction inputs, see: https://learnmeabitcoin.com/technical/transaction/#structure-inputs-txid*


```solidity
struct BtcTxIn {
    bytes32 txId;
    uint32 vout;
    uint32 sequence;
    bytes scriptSig;
}
```

