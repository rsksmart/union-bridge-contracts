# BtcTxIn
[Git Source](https://github.com/FairgateLabs/bitvmx-union-bridge-contracts/blob/b656e8c68a46e57c80c7029f9deb9e4b65b60046/src/interfaces/IBitcoinManager.sol)

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

