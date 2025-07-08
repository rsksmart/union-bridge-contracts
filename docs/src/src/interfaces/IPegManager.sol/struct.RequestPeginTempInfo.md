# RequestPeginTempInfo
[Git Source](https://github.com/FairgateLabs/bitvmx-union-bridge-contracts/blob/88ae00b3e8fb636de955be6f15b3c84ce2cc3729/src/interfaces/IPegManager.sol)

Temporary information stored during peg-in request processing

*Contains data needed for the accept peg-in phase*


```solidity
struct RequestPeginTempInfo {
    address rskDestinationAddress;
    bytes32 btcReimbursementPubKey;
    bytes32 acceptPeginSignatureHash;
}
```

