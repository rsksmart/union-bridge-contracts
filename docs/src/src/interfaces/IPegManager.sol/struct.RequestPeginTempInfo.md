# RequestPeginTempInfo
[Git Source](https://github.com/FairgateLabs/bitvmx-union-bridge-contracts/blob/d1d7e57632b0c5f559c5c50994a17b0f4b09c742/src/interfaces/IPegManager.sol)

Temporary information stored during peg-in request processing

*Contains data needed for the accept peg-in phase*


```solidity
struct RequestPeginTempInfo {
    address rskDestinationAddress;
    bytes32 btcReimbursementPubKey;
    bytes32 acceptPeginSignatureHash;
}
```

