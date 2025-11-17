# BtcTxSPVProof
[Git Source](https://github.com/FairgateLabs/bitvmx-union-bridge-contracts/blob/b656e8c68a46e57c80c7029f9deb9e4b65b60046/src/interfaces/IPegCommonTypes.sol)

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

