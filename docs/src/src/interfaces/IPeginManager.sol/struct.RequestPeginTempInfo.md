# RequestPeginTempInfo
[Git Source](https://github.com/temp-rsk/bitvmx-union-bridge-contracts/blob/aa0c5b500b0a03f68164877ee0ab01eebfbdfa68/src/interfaces/IPeginManager.sol)

Temporary information stored during peg-in request processing

*Contains data needed for the accept peg-in phase*


```solidity
struct RequestPeginTempInfo {
    address rskDestinationAddress;
    bytes32 btcReimbursementPubKey;
    bytes32 acceptPeginSignatureHash;
    int256 btcBlockNumber;
    bytes32 userReimbursementTxid;
    bytes32 rejectPeginTxid;
}
```

