# BtcTxSPVProof
[Git Source](https://github.com/temp-rsk/bitvmx-union-bridge-contracts/blob/ee0115174aa9f16d975ad140f940d23fb1883b23/src/interfaces/IPegCommonTypes.sol)

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

