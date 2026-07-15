# BitcoinSignatureData
[Git Source](https://github.com/rsksmart/union-bridge-contracts/blob/b56fdca4d854a3d344854107131d121e04834d63/src/interfaces/IBitcoinManager.sol)

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

