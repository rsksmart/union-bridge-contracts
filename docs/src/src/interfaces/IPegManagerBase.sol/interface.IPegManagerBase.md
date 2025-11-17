# IPegManagerBase
[Git Source](https://github.com/FairgateLabs/bitvmx-union-bridge-contracts/blob/b656e8c68a46e57c80c7029f9deb9e4b65b60046/src/interfaces/IPegManagerBase.sol)

Interface for shared functionality between PeginManager and PegoutManager


## Functions
### bitcoinManager

Returns the bitcoin manager contract


```solidity
function bitcoinManager() external view returns (IBitcoinManager);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`IBitcoinManager`|The bitcoin manager contract|


### streamManager

Returns the stream manager contract


```solidity
function streamManager() external view returns (IStreamManager);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`IStreamManager`|The stream manager contract|


### committeeRegistry

Returns the committee registry contract


```solidity
function committeeRegistry() external view returns (ICommitteeRegistry);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`ICommitteeRegistry`|The committee registry contract|


### signatureManager

Returns the signature manager contract


```solidity
function signatureManager() external view returns (ISignatureManager);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`ISignatureManager`|The signature manager contract|


### setStreamManager

Sets the stream manager contract address


```solidity
function setStreamManager(IStreamManager _streamManager) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_streamManager`|`IStreamManager`|The stream manager contract address|


### setSignatureManager

Sets the signature manager contract address


```solidity
function setSignatureManager(ISignatureManager _signatureManager) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_signatureManager`|`ISignatureManager`|The signature manager contract address|


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

### SignatureManagerUpdated
Emitted when the signature manager is updated


```solidity
event SignatureManagerUpdated(ISignatureManager _signatureManager);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_signatureManager`|`ISignatureManager`|The new signature manager address|

## Errors
### BitcoinManagerAddressZero
Error thrown when bitcoin manager address is zero


```solidity
error BitcoinManagerAddressZero();
```

### CommitteeRegistryAddressZero
Error thrown when committee registry address is zero


```solidity
error CommitteeRegistryAddressZero();
```

### SignatureManagerAddressZero
Error thrown when signature manager address is zero


```solidity
error SignatureManagerAddressZero();
```

### StreamManagerAddressZero
Error thrown when stream manager address is zero


```solidity
error StreamManagerAddressZero();
```

### RbtcBridgeAddressZero
Error thrown when RbtcBridge address is zero


```solidity
error RbtcBridgeAddressZero();
```

