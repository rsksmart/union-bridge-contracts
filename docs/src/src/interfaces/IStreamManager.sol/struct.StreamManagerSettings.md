# StreamManagerSettings
[Git Source](https://github.com/temp-rsk/bitvmx-union-bridge-contracts/blob/2c7f90ba21d83a98b646123c60d27a00fe0644fd/src/interfaces/IStreamManager.sol)


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

