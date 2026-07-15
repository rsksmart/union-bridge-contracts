# Balance
[Git Source](https://github.com/rsksmart/union-bridge-contracts/blob/b56fdca4d854a3d344854107131d121e04834d63/src/interfaces/ICommitteeRegistry.sol)

Represents the balance and application staking information for a member

*Tracks available balance, applications, and staked amounts across packets*


```solidity
struct Balance {
    uint256 available;
    ApplicationData[] applications;
    mapping(uint64 packetNumber => uint256 amount)[] staked;
}
```

