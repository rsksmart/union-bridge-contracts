# RequestPeginTempInfo
[Git Source](https://github.com/FairgateLabs/bitvmx-union-bridge-contracts/blob/b656e8c68a46e57c80c7029f9deb9e4b65b60046/src/interfaces/IPeginManager.sol)

Temporary information stored during peg-in request processing

*Contains data needed for the accept peg-in phase*


```solidity
struct RequestPeginTempInfo {
    address rskDestinationAddress;
    bytes32 btcReimbursementPubKey;
    bytes32 acceptPeginSignatureHash;
}
```

