# BtcTxSPVProof
[Git Source](https://github.com/temp-rsk/bitvmx-union-bridge-contracts/blob/71daf3bfeba3a077e1d33188a46c6e2cfea30519/src/interfaces/IPegManager.sol)

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

