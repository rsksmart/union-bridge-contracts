# IPegManagerBase
[Git Source](https://github.com/rsksmart/union-bridge-contracts/blob/6c85aeb17a23ee9d675a92f8655a551ecca7b4c9/src/interfaces/IPegManagerBase.sol)

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

