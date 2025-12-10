# PegoutManagerSettings
[Git Source](https://github.com/temp-rsk/bitvmx-union-bridge-contracts/blob/4c35e62294ee16f56ba26d52283a5d84868fbd84/src/interfaces/IPegoutManager.sol)

Settings for the PegoutManager contract

*Contains timeout configurations for peg-out operations*


```solidity
struct PegoutManagerSettings {
    uint256 userTakeTimeout;
    uint256 operatorTakeTimeout;
}
```

