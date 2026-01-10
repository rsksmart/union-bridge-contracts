# Member
[Git Source](https://github.com/temp-rsk/bitvmx-union-bridge-contracts/blob/71daf3bfeba3a077e1d33188a46c6e2cfea30519/src/interfaces/ICommitteeRegistry.sol)

Represents a committee member with their keys, roles, and balance

*Contains all information needed to manage a member's participation*


```solidity
struct Member {
    MemberKeys publicKeys;
    Balance balance;
    mapping(string key => string value) data;
}
```

