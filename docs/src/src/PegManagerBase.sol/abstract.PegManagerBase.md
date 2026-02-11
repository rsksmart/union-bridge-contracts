# PegManagerBase
[Git Source](https://github.com/temp-rsk/bitvmx-union-bridge-contracts/blob/6a9ea8ca3ca82c82894d3db0e338e4bf6bb46de8/src/PegManagerBase.sol)

**Inherits:**
[IPegManagerBase](/src/interfaces/IPegManagerBase.sol/interface.IPegManagerBase.md), [PegBase](/src/PegBase.sol/abstract.PegBase.md)

Abstract base contract for shared functionality between PeginManager and PegoutManager

*Contains common state variables, initialization logic, and setter functions*


## State Variables
### signatureManager
Signature manager contract for handling multi-signature operations


```solidity
ISignatureManager public signatureManager;
```


## Functions
### __PegManagerBase_init

Initializes the base PegManager contract

*This function should be called by child contracts during their initialization*


```solidity
function __PegManagerBase_init(
    address _initialOwner,
    address _accessManager,
    ICommitteeRegistry _committeeRegistry,
    IBitcoinManager _bitcoinManager,
    IRbtcBridge _rbtcBridge,
    IStreamManager _streamManager,
    ISignatureManager _signatureManager
) internal onlyInitializing;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_initialOwner`|`address`|The initial owner of the contract|
|`_accessManager`|`address`|The access manager contract address|
|`_committeeRegistry`|`ICommitteeRegistry`|The committee registry contract address|
|`_bitcoinManager`|`IBitcoinManager`|The Bitcoin manager contract address|
|`_rbtcBridge`|`IRbtcBridge`|The RbtcBridge contract for minting/burning RBTC|
|`_streamManager`|`IStreamManager`|The stream manager contract address|
|`_signatureManager`|`ISignatureManager`||


