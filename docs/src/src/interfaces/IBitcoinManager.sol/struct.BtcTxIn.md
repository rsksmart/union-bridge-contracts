# BtcTxIn
[Git Source](https://github.com/temp-rsk/bitvmx-union-bridge-contracts/blob/2c7f90ba21d83a98b646123c60d27a00fe0644fd/src/interfaces/IBitcoinManager.sol)

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

