# Member
[Git Source](https://github.com/rsksmart/union-bridge-contracts/blob/6c85aeb17a23ee9d675a92f8655a551ecca7b4c9/src/interfaces/IMemberRegistry.sol)

Represents a committee member with their keys, roles, and balance

*Contains all information needed to manage a member's participation*


```solidity
struct Member {
    MemberKeys publicKeys;
    Balance balance;
    mapping(string key => string value) data;
}
```

