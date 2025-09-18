# PegoutTempInfo
[Git Source](https://github.com/FairgateLabs/bitvmx-union-bridge-contracts/blob/b91181b0a4bd785ef0099b4b80f38101dfa816d0/src/interfaces/IPegManager.sol)

Temporary information stored during peg-out processing

*Contains data needed for peg-out transaction validation*


```solidity
struct PegoutTempInfo {
    bytes userPubKey;
    uint256 createdAt;
    uint256 operatorTakeUpdatedAt;
    uint128 committeeId;
    address takeOperatorAddress;
    bytes32 takeOperatorPubKey;
}
```

