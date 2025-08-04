# Balance
[Git Source](https://github.com/FairgateLabs/bitvmx-union-bridge-contracts/blob/b41d024ed73655cc3c392a6c92b6259ef625d19d/src/interfaces/ICommitteeRegistry.sol)

Represents the balance and application staking information for a member

*Tracks available balance, applications, and staked amounts across packets*


```solidity
struct Balance {
    uint256 available;
    ApplicationData[] applications;
    mapping(uint64 packetNumber => uint256 amount)[] staked;
}
```

