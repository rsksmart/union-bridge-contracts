# BitcoinSignatureData
[Git Source](https://github.com/temp-rsk/bitvmx-union-bridge-contracts/blob/96535706e496364789ce242b18e17052bb6e424e/src/interfaces/IBitcoinManager.sol)

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

