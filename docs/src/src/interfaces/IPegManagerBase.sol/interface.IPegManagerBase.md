# IPegManagerBase
[Git Source](https://github.com/rsksmart/union-bridge-contracts/blob/68c14faa89612dfba1b7e9abf29455625661476f/src/interfaces/IPegManagerBase.sol)

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

