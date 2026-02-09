# ApplicationData
[Git Source](https://github.com/temp-rsk/bitvmx-union-bridge-contracts/blob/835a0374fad05fe95d66ed5d56f02d5826093237/src/interfaces/ICommitteeRegistry.sol)

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

