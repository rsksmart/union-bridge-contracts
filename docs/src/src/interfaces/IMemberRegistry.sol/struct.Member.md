# Member
[Git Source](https://github.com/temp-rsk/bitvmx-union-bridge-contracts/blob/bd6b4a28bf5973e554d9b7a237190a44cdd46b38/src/interfaces/IMemberRegistry.sol)

Represents a committee member with their keys, roles, and balance

*Contains all information needed to manage a member's participation*


```solidity
struct Member {
    MemberKeys publicKeys;
    Balance balance;
    mapping(string key => string value) data;
}
```

