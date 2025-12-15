# Member
[Git Source](https://github.com/temp-rsk/bitvmx-union-bridge-contracts/blob/96535706e496364789ce242b18e17052bb6e424e/src/interfaces/ICommitteeRegistry.sol)

Represents a committee member with their keys, roles, and balance

*Contains all information needed to manage a member's participation*


```solidity
struct Member {
    MemberKeys publicKeys;
    Balance balance;
    mapping(string key => string value) data;
}
```

