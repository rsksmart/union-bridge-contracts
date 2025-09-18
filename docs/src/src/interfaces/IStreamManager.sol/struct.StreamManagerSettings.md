# StreamManagerSettings
[Git Source](https://github.com/FairgateLabs/bitvmx-union-bridge-contracts/blob/b91181b0a4bd785ef0099b4b80f38101dfa816d0/src/interfaces/IStreamManager.sol)


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

