# PegoutStartInfo
[Git Source](https://github.com/temp-rsk/bitvmx-union-bridge-contracts/blob/bd6b4a28bf5973e554d9b7a237190a44cdd46b38/src/interfaces/IPegoutManager.sol)

Start info stored in PegoutManager (user take / pegout creation only)


```solidity
struct PegoutStartInfo {
    bytes userPubKey;
    uint256 createdAt;
    bytes32 pegoutTxid;
}
```

