# StreamSettings
[Git Source](https://github.com/rsksmart/union-bridge-contracts/blob/6c85aeb17a23ee9d675a92f8655a551ecca7b4c9/src/interfaces/IStreamManager.sol)


```solidity
struct StreamSettings {
    uint64 denomination;
    uint8 peginConfirmations;
    uint8 rejectPeginConfirmations;
    uint8 pegoutConfirmations;
    TimelockSettings timelockSettings;
}
```

