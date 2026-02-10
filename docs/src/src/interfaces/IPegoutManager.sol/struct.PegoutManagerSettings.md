# PegoutManagerSettings
[Git Source](https://github.com/temp-rsk/bitvmx-union-bridge-contracts/blob/6a9ea8ca3ca82c82894d3db0e338e4bf6bb46de8/src/interfaces/IPegoutManager.sol)

Settings for the PegoutManager contract

*Contains timeout configurations in seconds for peg-out operations*


```solidity
struct PegoutManagerSettings {
    uint256 userTakeTimeout;
    uint256 operatorTakeTimeout;
}
```

