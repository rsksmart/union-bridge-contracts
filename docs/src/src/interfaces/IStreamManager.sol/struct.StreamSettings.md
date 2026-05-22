# StreamSettings
[Git Source](https://github.com/rsksmart/union-bridge-contracts/blob/dd34207db3c68e4260aba3e2d2660c73733e6970/src/interfaces/IStreamManager.sol)


```solidity
struct StreamSettings {
    uint64 denomination;
    uint8 peginConfirmations;
    uint8 rejectPeginConfirmations;
    uint8 pegoutConfirmations;
    TimelockSettings timelockSettings;
}
```

