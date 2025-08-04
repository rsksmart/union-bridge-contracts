# Member
[Git Source](https://github.com/FairgateLabs/bitvmx-union-bridge-contracts/blob/b41d024ed73655cc3c392a6c92b6259ef625d19d/src/interfaces/ICommitteeRegistry.sol)

Represents a committee member with their keys, roles, and balance

*Contains all information needed to manage a member's participation*


```solidity
struct Member {
    MemberKeys publicKeys;
    Balance balance;
    mapping(string key => string value) data;
}
```

