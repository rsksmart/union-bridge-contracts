# PegoutManagerSettings
[Git Source](https://github.com/FairgateLabs/bitvmx-union-bridge-contracts/blob/b656e8c68a46e57c80c7029f9deb9e4b65b60046/src/interfaces/IPegoutManager.sol)

Settings for the PegoutManager contract

*Contains timeout configurations for peg-out operations*


```solidity
struct PegoutManagerSettings {
    uint256 userTakeTimeout;
    uint256 operatorTakeTimeout;
}
```

