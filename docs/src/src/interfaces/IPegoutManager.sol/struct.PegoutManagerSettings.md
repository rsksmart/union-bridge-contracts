# PegoutManagerSettings
[Git Source](https://github.com/rsksmart/union-bridge-contracts/blob/68c14faa89612dfba1b7e9abf29455625661476f/src/interfaces/IPegoutManager.sol)

Settings for the PegoutManager contract

*Contains timeout configurations in seconds for peg-out operations*


```solidity
struct PegoutManagerSettings {
    uint256 userTakeTimeout;
    uint256 operatorTakeTimeout;
}
```

