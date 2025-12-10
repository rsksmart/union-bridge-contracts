# ApplicationData
[Git Source](https://github.com/temp-rsk/bitvmx-union-bridge-contracts/blob/4c35e62294ee16f56ba26d52283a5d84868fbd84/src/interfaces/ICommitteeRegistry.sol)

Represents application data for a member's role request

*Contains the requested role, pre-staked amount, and funding UTXO*


```solidity
struct ApplicationData {
    Role requestedRole;
    uint256 preStaked;
    bool reApply;
    UTXO fundingUTXO;
}
```

