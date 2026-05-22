# PegoutTempInfo
[Git Source](https://github.com/rsksmart/union-bridge-contracts/blob/68c14faa89612dfba1b7e9abf29455625661476f/src/interfaces/IPegoutManager.sol)

Temporary information stored during peg-out processing

*Contains data needed for peg-out transaction validation*


```solidity
struct PegoutTempInfo {
    bytes userPubKey;
    uint256 createdAt;
    uint256 operatorTakeUpdatedAt;
    uint128 committeeId;
    address takeOperatorAddress;
    bytes32 operatorTakePubKey;
    bytes32 operatorDisputePubKey;
    bytes32 pegoutId;
    int256 advanceFundsBlockNumber;
    bytes32 reimbursementKickoffTxid;
}
```

