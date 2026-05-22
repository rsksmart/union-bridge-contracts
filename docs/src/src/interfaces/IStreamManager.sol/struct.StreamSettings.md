# StreamSettings
[Git Source](https://github.com/rsksmart/union-bridge-contracts/blob/cf5421e1f47ca597147a56a1404f8189f6c70b20/src/interfaces/IStreamManager.sol)


```solidity
struct StreamSettings {
    uint64 denomination;
    uint8 peginConfirmations;
    uint8 rejectPeginConfirmations;
    uint8 pegoutConfirmations;
    TimelockSettings timelockSettings;
}
```

