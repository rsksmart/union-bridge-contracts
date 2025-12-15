# PegManagerBase
[Git Source](https://github.com/temp-rsk/bitvmx-union-bridge-contracts/blob/96535706e496364789ce242b18e17052bb6e424e/src/PegManagerBase.sol)

**Inherits:**
[IPegManagerBase](/src/interfaces/IPegManagerBase.sol/interface.IPegManagerBase.md), [BaseProxy](/src/BaseProxy.sol/abstract.BaseProxy.md), [ProofValidator](/src/ProofValidator.sol/abstract.ProofValidator.md), ReentrancyGuardUpgradeable, [Pausable](/src/Pausable.sol/contract.Pausable.md)

Abstract base contract for shared functionality between PeginManager and PegoutManager

*Contains common state variables, initialization logic, and setter functions*


## State Variables
### bitcoinManager
Bitcoin manager contract for Bitcoin transaction validation and address generation


```solidity
IBitcoinManager public bitcoinManager;
```


### streamManager
Stream manager contract for managing union bridge streams and slots


```solidity
IStreamManager public streamManager;
```


### committeeRegistry
Committee registry contract for managing committee and members


```solidity
ICommitteeRegistry public committeeRegistry;
```


### signatureManager
Signature manager contract for handling multi-signature operations


```solidity
ISignatureManager public signatureManager;
```


### rbtcBridge
The RbtcBridge contract for minting RBTC


```solidity
IRbtcBridge public rbtcBridge;
```


## Functions
### __PegManagerBase_init

Initializes the base PegManager contract

*This function should be called by child contracts during their initialization*


```solidity
function __PegManagerBase_init(
    address _initialOwner,
    address payable _bridgeAddress,
    ICommitteeRegistry _committeeRegistry,
    IBitcoinManager _bitcoinManager,
    IRbtcBridge _rbtcBridge
) internal onlyInitializing;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_initialOwner`|`address`|The initial owner of the contract|
|`_bridgeAddress`|`address payable`|The address of the pow-peg bridge contract|
|`_committeeRegistry`|`ICommitteeRegistry`|The committee registry contract address|
|`_bitcoinManager`|`IBitcoinManager`|The Bitcoin manager contract address|
|`_rbtcBridge`|`IRbtcBridge`||


### setStreamManager

Sets the stream manager contract address

*Only callable by the contract owner*


```solidity
function setStreamManager(IStreamManager _streamManager) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_streamManager`|`IStreamManager`|The stream manager contract address|


### setSignatureManager

Sets the signature manager contract address

*Only callable by the contract owner*


```solidity
function setSignatureManager(ISignatureManager _signatureManager) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_signatureManager`|`ISignatureManager`|The signature manager contract address|


### setPauser

Sets a new pauser address

*Only callable by the contract owner*


```solidity
function setPauser(address _newPauser) public override onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_newPauser`|`address`|The new pauser address|


