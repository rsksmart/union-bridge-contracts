# StreamManagerSettings
[Git Source](https://github.com/temp-rsk/bitvmx-union-bridge-contracts/blob/71daf3bfeba3a077e1d33188a46c6e2cfea30519/src/interfaces/IStreamManager.sol)


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

