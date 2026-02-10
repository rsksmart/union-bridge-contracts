# ChainIds
[Git Source](https://github.com/temp-rsk/bitvmx-union-bridge-contracts/blob/6a9ea8ca3ca82c82894d3db0e338e4bf6bb46de8/src/libraries/Network.sol)

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


### RSK_REGTEST
RSK Regtest


```solidity
uint256 constant RSK_REGTEST = 33;
```


### LOCAL
Local development network (Hardhat/Foundry default)

*Used for local testing and development environments*


```solidity
uint256 constant LOCAL = 31337;
```


