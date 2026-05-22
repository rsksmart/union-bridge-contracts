# IPegManagerBase
[Git Source](https://github.com/rsksmart/union-bridge-contracts/blob/dd34207db3c68e4260aba3e2d2660c73733e6970/src/interfaces/IPegManagerBase.sol)

**Inherits:**
[IPegBase](/src/interfaces/IPegBase.sol/interface.IPegBase.md)

Interface for shared functionality between PeginManager and PegoutManager


## Events
### SignatureManagerUpdated
Emitted when the signature manager is updated


```solidity
event SignatureManagerUpdated(ISignatureManager _signatureManager);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_signatureManager`|`ISignatureManager`|The new signature manager address|

