# PegoutStartInfo
[Git Source](https://github.com/temp-rsk/bitvmx-union-bridge-contracts/blob/ee0115174aa9f16d975ad140f940d23fb1883b23/src/interfaces/IPegoutManager.sol)

Start info stored in PegoutManager (user take / pegout creation only)


```solidity
struct PegoutStartInfo {
    bytes userPubKey;
    uint256 createdAt;
    bytes32 pegoutTxid;
}
```

