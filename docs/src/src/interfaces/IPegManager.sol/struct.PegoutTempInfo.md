# PegoutTempInfo
[Git Source](https://github.com/FairgateLabs/bitvmx-union-bridge-contracts/blob/d1d7e57632b0c5f559c5c50994a17b0f4b09c742/src/interfaces/IPegManager.sol)

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

