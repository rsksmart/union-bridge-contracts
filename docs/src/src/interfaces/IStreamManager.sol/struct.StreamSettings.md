# StreamSettings
[Git Source](https://github.com/temp-rsk/bitvmx-union-bridge-contracts/blob/aa0c5b500b0a03f68164877ee0ab01eebfbdfa68/src/interfaces/IStreamManager.sol)


```solidity
struct StreamSettings {
    uint64 denomination;
    uint8 peginConfirmations;
    uint8 pegoutConfirmations;
    TimelockSettings timelockSettings;
}
```

