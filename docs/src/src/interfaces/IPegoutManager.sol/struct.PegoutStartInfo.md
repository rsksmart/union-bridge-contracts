# PegoutStartInfo
[Git Source](https://github.com/rsksmart/union-bridge-contracts/blob/dd34207db3c68e4260aba3e2d2660c73733e6970/src/interfaces/IPegoutManager.sol)

Start info stored in PegoutManager (user take / pegout creation only)


```solidity
struct PegoutStartInfo {
    bytes userPubKey;
    uint256 createdAt;
    bytes32 pegoutTxid;
}
```

