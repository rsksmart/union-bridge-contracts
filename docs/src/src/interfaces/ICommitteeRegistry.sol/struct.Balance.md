# Balance
[Git Source](https://github.com/FairgateLabs/bitvmx-union-bridge-contracts/blob/b91181b0a4bd785ef0099b4b80f38101dfa816d0/src/interfaces/ICommitteeRegistry.sol)

Represents the balance and application staking information for a member

*Tracks available balance, applications, and staked amounts across packets*


```solidity
struct Balance {
    uint256 available;
    ApplicationData[] applications;
    mapping(uint64 packetNumber => uint256 amount)[] staked;
}
```

