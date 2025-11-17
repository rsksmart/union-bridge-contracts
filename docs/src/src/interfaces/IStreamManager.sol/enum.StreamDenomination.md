# StreamDenomination
[Git Source](https://github.com/FairgateLabs/bitvmx-union-bridge-contracts/blob/b656e8c68a46e57c80c7029f9deb9e4b65b60046/src/interfaces/IStreamManager.sol)

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

