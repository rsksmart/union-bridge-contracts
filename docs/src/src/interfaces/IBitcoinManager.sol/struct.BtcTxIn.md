# BtcTxIn
[Git Source](https://github.com/FairgateLabs/bitvmx-union-bridge-contracts/blob/b91181b0a4bd785ef0099b4b80f38101dfa816d0/src/interfaces/IBitcoinManager.sol)

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

