# ApplicationData
[Git Source](https://github.com/FairgateLabs/bitvmx-union-bridge-contracts/blob/b41d024ed73655cc3c392a6c92b6259ef625d19d/src/interfaces/ICommitteeRegistry.sol)

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

