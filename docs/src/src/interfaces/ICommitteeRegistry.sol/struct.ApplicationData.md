# ApplicationData
[Git Source](https://github.com/temp-rsk/bitvmx-union-bridge-contracts/blob/96535706e496364789ce242b18e17052bb6e424e/src/interfaces/ICommitteeRegistry.sol)

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

