# StreamSettings
[Git Source](https://github.com/temp-rsk/bitvmx-union-bridge-contracts/blob/835a0374fad05fe95d66ed5d56f02d5826093237/src/interfaces/IStreamManager.sol)


```solidity
struct StreamSettings {
    uint64 denomination;
    uint8 peginConfirmations;
    uint8 pegoutConfirmations;
    TimelockSettings timelockSettings;
}
```

