# IPegManagerBase
[Git Source](https://github.com/rsksmart/union-bridge-contracts/blob/cf5421e1f47ca597147a56a1404f8189f6c70b20/src/interfaces/IPegManagerBase.sol)

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

