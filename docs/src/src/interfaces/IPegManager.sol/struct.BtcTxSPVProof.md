# BtcTxSPVProof
[Git Source](https://github.com/FairgateLabs/bitvmx-union-bridge-contracts/blob/9f14e34a8636f5a1e820830e7bebc3a177006c7a/src/interfaces/IPegManager.sol)

Represents a Bitcoin transaction with SPV proof for bridge validation

*Contains the transaction data along with merkle proof for block inclusion verification*

*Used to prove that a Bitcoin transaction is included in a specific block without full node verification*


```solidity
struct BtcTxSPVProof {
    bytes32 blockHash;
    BtcTransaction btcTx;
    uint256 merkleBranchPath;
    bytes32[] merkleBranchHashes;
}
```

