# StreamManagerSettings
[Git Source](https://github.com/FairgateLabs/bitvmx-union-bridge-contracts/blob/0b531d846dee21847f46b6304e71a6006a2ef7c3/src/interfaces/IStreamManager.sol)


```solidity
struct StreamManagerSettings {
    uint8 peginConfirmations;
    uint8 pegoutConfirmations;
    uint16 securityBondPercentageOperator;
    uint16 securityBondPercentageWatchtower;
    uint256 minimumSecurityDeposit;
    uint256 disablementPaymentsPerChallenge;
}
```

