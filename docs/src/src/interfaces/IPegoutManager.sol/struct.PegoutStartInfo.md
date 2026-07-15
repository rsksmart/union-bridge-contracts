# PegoutStartInfo
[Git Source](https://github.com/rsksmart/union-bridge-contracts/blob/6c85aeb17a23ee9d675a92f8655a551ecca7b4c9/src/interfaces/IPegoutManager.sol)

Start info stored in PegoutManager (user take / pegout creation only)


```solidity
struct PegoutStartInfo {
    bytes userPubKey;
    uint256 createdAt;
    bytes32 pegoutTxid;
}
```

