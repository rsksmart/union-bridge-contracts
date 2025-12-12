# PegoutTempInfo
[Git Source](https://github.com/temp-rsk/bitvmx-union-bridge-contracts/blob/13960dd321557c932048de4fc7353af5ceae0b8d/src/interfaces/IPegoutManager.sol)

Temporary information stored during peg-out processing

*Contains data needed for peg-out transaction validation*


```solidity
struct PegoutTempInfo {
    bytes userPubKey;
    uint256 createdAt;
    uint256 operatorTakeUpdatedAt;
    uint128 committeeId;
    address takeOperatorAddress;
    bytes32 operatorDisputePubKey;
}
```

