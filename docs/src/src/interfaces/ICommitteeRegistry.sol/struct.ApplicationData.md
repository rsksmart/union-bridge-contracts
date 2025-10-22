# ApplicationData
[Git Source](https://github.com/FairgateLabs/bitvmx-union-bridge-contracts/blob/d1d7e57632b0c5f559c5c50994a17b0f4b09c742/src/interfaces/ICommitteeRegistry.sol)

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

