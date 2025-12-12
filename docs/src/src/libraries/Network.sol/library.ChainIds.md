# ChainIds
[Git Source](https://github.com/temp-rsk/bitvmx-union-bridge-contracts/blob/13960dd321557c932048de4fc7353af5ceae0b8d/src/libraries/Network.sol)

Library containing chain ID constants for different RSK networks

*Provides standardized chain IDs for RSK mainnet, testnet and local networks*


## State Variables
### RSK_MAINNET
RSK mainnet - the production network


```solidity
uint256 constant RSK_MAINNET = 30;
```


### RSK_TESTNET
RSK testnet - the public test network


```solidity
uint256 constant RSK_TESTNET = 31;
```


### LOCAL
Local development network (Hardhat/Foundry default)

*Used for local testing and development environments*


```solidity
uint256 constant LOCAL = 31337;
```


