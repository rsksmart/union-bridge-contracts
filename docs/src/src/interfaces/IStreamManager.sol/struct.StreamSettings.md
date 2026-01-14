# StreamSettings
[Git Source](https://github.com/temp-rsk/bitvmx-union-bridge-contracts/blob/0c819fa3fad6abf73f5f2a830cc21b001080582f/src/interfaces/IStreamManager.sol)


```solidity
struct StreamSettings {
    uint64 denomination;
    uint8 peginConfirmations;
    uint8 pegoutConfirmations;
    TimelockSettings timelockSettings;
}
```

