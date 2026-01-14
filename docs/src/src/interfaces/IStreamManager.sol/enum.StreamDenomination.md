# StreamDenomination
[Git Source](https://github.com/temp-rsk/bitvmx-union-bridge-contracts/blob/0c819fa3fad6abf73f5f2a830cc21b001080582f/src/interfaces/IStreamManager.sol)

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

