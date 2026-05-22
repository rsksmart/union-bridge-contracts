# Balance
[Git Source](https://github.com/rsksmart/union-bridge-contracts/blob/dd34207db3c68e4260aba3e2d2660c73733e6970/src/interfaces/IMemberRegistry.sol)

Represents the balance and application staking information for a member

*Tracks available balance, applications, and staked amounts across packets*


```solidity
struct Balance {
    uint256 available;
    ApplicationData[] applications;
    mapping(uint64 packetNumber => uint256 amount)[] staked;
}
```

