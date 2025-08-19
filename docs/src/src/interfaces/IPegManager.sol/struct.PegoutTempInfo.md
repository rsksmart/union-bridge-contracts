# PegoutTempInfo
[Git Source](https://github.com/FairgateLabs/bitvmx-union-bridge-contracts/blob/b750ea532307d08987643fe249271c69c1bee159/src/interfaces/IPegManager.sol)

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

