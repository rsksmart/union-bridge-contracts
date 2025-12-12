# PegoutManagerSettings
[Git Source](https://github.com/temp-rsk/bitvmx-union-bridge-contracts/blob/13960dd321557c932048de4fc7353af5ceae0b8d/src/interfaces/IPegoutManager.sol)

Settings for the PegoutManager contract

*Contains timeout configurations for peg-out operations*


```solidity
struct PegoutManagerSettings {
    uint256 userTakeTimeout;
    uint256 operatorTakeTimeout;
}
```

