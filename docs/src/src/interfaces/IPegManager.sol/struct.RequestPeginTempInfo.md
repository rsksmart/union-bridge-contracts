# RequestPeginTempInfo
[Git Source](https://github.com/FairgateLabs/bitvmx-union-bridge-contracts/blob/0b531d846dee21847f46b6304e71a6006a2ef7c3/src/interfaces/IPegManager.sol)

Temporary information stored during peg-in request processing

*Contains data needed for the accept peg-in phase*


```solidity
struct RequestPeginTempInfo {
    address rskDestinationAddress;
    bytes32 btcReimbursementPubKey;
    bytes32 acceptPeginSignatureHash;
}
```

