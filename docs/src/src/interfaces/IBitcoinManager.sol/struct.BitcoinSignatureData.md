# BitcoinSignatureData
[Git Source](https://github.com/temp-rsk/bitvmx-union-bridge-contracts/blob/13960dd321557c932048de4fc7353af5ceae0b8d/src/interfaces/IBitcoinManager.sol)

Data structure for Bitcoin transaction signature information

*Used by both accept peg-in and peg-out signature generation functions*


```solidity
struct BitcoinSignatureData {
    BtcTransaction tx;
    bytes32 txid;
    bytes32 signatureHash;
    bytes signatureMessage;
}
```

