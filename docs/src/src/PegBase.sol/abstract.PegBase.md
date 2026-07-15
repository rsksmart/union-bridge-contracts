# PegBase
[Git Source](https://github.com/rsksmart/union-bridge-contracts/blob/cf5421e1f47ca597147a56a1404f8189f6c70b20/src/PegBase.sol)

**Inherits:**
[IPegBase](/src/interfaces/IPegBase.sol/interface.IPegBase.md), [BaseProxy](/src/BaseProxy.sol/abstract.BaseProxy.md), [Pausable](/src/Pausable.sol/abstract.Pausable.md), ReentrancyGuardUpgradeable

Abstract base contract for shared functionality between PeginManager, PegoutManager and ChallengeManager

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


### accessManager

```solidity
AccessManager public accessManager;
```


### rbtcBridge
The rbtc bridge contract


```solidity
IRbtcBridge public rbtcBridge;
```


## Functions
### __PegBase_init

Initializes the base PegBase contract

*This function should be called by child contracts during their initialization*


```solidity
function __PegBase_init(
    address _initialOwner,
    address _accessManager,
    ICommitteeRegistry _committeeRegistry,
    IBitcoinManager _bitcoinManager,
    IRbtcBridge _rbtcBridge,
    IStreamManager _streamManager
) internal onlyInitializing;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_initialOwner`|`address`|The initial owner of the contract|
|`_accessManager`|`address`|The access manager contract address|
|`_committeeRegistry`|`ICommitteeRegistry`|The committee registry contract address|
|`_bitcoinManager`|`IBitcoinManager`|The Bitcoin manager contract address|
|`_rbtcBridge`|`IRbtcBridge`|The rbtc bridge contract for verifying Bitcoin transaction confirmations|
|`_streamManager`|`IStreamManager`|The stream manager contract address|


