# StreamManagerSettings
[Git Source](https://github.com/FairgateLabs/bitvmx-union-bridge-contracts/blob/5935b1ba9b5693ff58c693caac2763a4b158c822/src/interfaces/IStreamManager.sol)


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

