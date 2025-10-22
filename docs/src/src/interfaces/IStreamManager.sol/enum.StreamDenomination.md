# StreamDenomination
[Git Source](https://github.com/FairgateLabs/bitvmx-union-bridge-contracts/blob/d1d7e57632b0c5f559c5c50994a17b0f4b09c742/src/interfaces/IStreamManager.sol)

Represents different Bitcoin denominations supported by the union bridge

*Each denomination corresponds to a specific stream for efficient fund management*


```solidity
enum StreamDenomination {
    _0_001BTC,
    _0_01BTC,
    _0_1BTC,
    _1BTC,
    _10BTC,
    LENGTH
}
```

