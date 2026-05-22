# StreamDenomination
[Git Source](https://github.com/temp-rsk/bitvmx-union-bridge-contracts/blob/bd6b4a28bf5973e554d9b7a237190a44cdd46b38/src/interfaces/IStreamManager.sol)

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

