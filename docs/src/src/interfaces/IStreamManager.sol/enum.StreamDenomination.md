# StreamDenomination
[Git Source](https://github.com/rsksmart/union-bridge-contracts/blob/dd34207db3c68e4260aba3e2d2660c73733e6970/src/interfaces/IStreamManager.sol)

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

