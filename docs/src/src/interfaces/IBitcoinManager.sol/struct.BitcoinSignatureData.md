# BitcoinSignatureData
[Git Source](https://github.com/temp-rsk/bitvmx-union-bridge-contracts/blob/0c819fa3fad6abf73f5f2a830cc21b001080582f/src/interfaces/IBitcoinManager.sol)

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

