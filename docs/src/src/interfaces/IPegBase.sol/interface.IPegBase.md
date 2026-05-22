# IPegBase
[Git Source](https://github.com/rsksmart/union-bridge-contracts/blob/cf5421e1f47ca597147a56a1404f8189f6c70b20/src/interfaces/IPegBase.sol)

**Inherits:**
[IPausable](/src/interfaces/IPausable.sol/interface.IPausable.md)

Interface for the base contract for PeginManager, PegoutManager and ChallengeManager


## Events
### StreamManagerUpdated
Emitted when the stream manager is updated


```solidity
event StreamManagerUpdated(IStreamManager _streamManager);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_streamManager`|`IStreamManager`|The new stream manager address|

## Errors
### PeginNotRequested
Thrown when trying to process a peg-out for a peg-in that hasn't been requested


```solidity
error PeginNotRequested(bytes32 btcTxid);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`btcTxid`|`bytes32`|The Bitcoin transaction id that wasn't requested|

### InvalidPegStatus
Thrown when the peg status is not valid for the current operation


```solidity
error InvalidPegStatus(PegStatus actual);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`actual`|`PegStatus`|The actual peg status that was found|

