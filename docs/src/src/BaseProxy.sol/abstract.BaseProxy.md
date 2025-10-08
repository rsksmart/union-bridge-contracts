# BaseProxy
[Git Source](https://github.com/FairgateLabs/bitvmx-union-bridge-contracts/blob/0b531d846dee21847f46b6304e71a6006a2ef7c3/src/BaseProxy.sol)

**Inherits:**
UUPSUpgradeable, OwnableUpgradeable

Abstract base contract for upgradeable proxy contracts

*Provides UUPS upgradeability and ownership functionality*

*Inherits from OpenZeppelin's UUPSUpgradeable and OwnableUpgradeable*


## Functions
### constructor

**Note:**
oz-upgrades-unsafe-allow: constructor


```solidity
constructor();
```

### __BaseProxy_init

Initializes the BaseProxy contract

*Sets up the initial owner for the contract*

*Can only be called once during contract deployment*


```solidity
function __BaseProxy_init(address _initialOwner) public initializer;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_initialOwner`|`address`|The address that will be set as the initial owner|


### _authorizeUpgrade


```solidity
function _authorizeUpgrade(address) internal override onlyOwner;
```

### getImplementation

Gets the current implementation address of the proxy

*Returns the address of the implementation contract behind the proxy*


```solidity
function getImplementation() external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The address of the current implementation contract|


