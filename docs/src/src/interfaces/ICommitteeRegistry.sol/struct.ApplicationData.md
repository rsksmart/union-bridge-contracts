# ApplicationData
[Git Source](https://github.com/FairgateLabs/bitvmx-union-bridge-contracts/blob/88ae00b3e8fb636de955be6f15b3c84ce2cc3729/src/interfaces/ICommitteeRegistry.sol)

Represents application data for a member's role request

*Contains the requested role and pre-staked amount*


```solidity
struct ApplicationData {
    Role requestedRole;
    uint256 preStaked;
    bool reApply;
}
```

