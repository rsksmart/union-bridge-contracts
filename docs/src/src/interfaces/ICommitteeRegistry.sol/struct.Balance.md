# Balance
[Git Source](https://github.com/temp-rsk/bitvmx-union-bridge-contracts/blob/835a0374fad05fe95d66ed5d56f02d5826093237/src/interfaces/ICommitteeRegistry.sol)

Represents the balance and application staking information for a member

*Tracks available balance, applications, and staked amounts across packets*


```solidity
struct Balance {
    uint256 available;
    ApplicationData[] applications;
    mapping(uint64 packetNumber => uint256 amount)[] staked;
}
```

