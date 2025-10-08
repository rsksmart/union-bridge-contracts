# BitcoinSignatureData
[Git Source](https://github.com/FairgateLabs/bitvmx-union-bridge-contracts/blob/5935b1ba9b5693ff58c693caac2763a4b158c822/src/interfaces/IBitcoinManager.sol)

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

