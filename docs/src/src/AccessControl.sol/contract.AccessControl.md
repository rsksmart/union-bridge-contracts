# AccessControl
[Git Source](https://github.com/FairgateLabs/bitvmx-union-bridge-contracts/blob/b750ea532307d08987643fe249271c69c1bee159/src/AccessControl.sol)

**Inherits:**
[IAccessControl](/src/interfaces/IAccessControl.sol/interface.IAccessControl.md), [BaseProxy](/src/BaseProxy.sol/abstract.BaseProxy.md)

Manages access control for the union bridge system

*Provides role-based access control with PegManager as the primary authorized account*

*Inherits from IAccessControl and BaseProxy for interface compliance and proxy functionality*


## State Variables
### pegManager
The address of the PegManager contract that has administrative privileges

*This address is authorized to call protected functions in contracts that inherit from AccessControl*


```solidity
address public pegManager;
```


## Functions
### constructor

**Note:**
oz-upgrades-unsafe-allow: constructor


```solidity
constructor();
```

### __AccessControl_init

Initializes the AccessControl contract

*Sets up the initial owner and PegManager address*

*Can only be called once during contract deployment*


```solidity
function __AccessControl_init(address _initialOwner, address _pegManager) public initializer;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_initialOwner`|`address`|The address that will be set as the initial owner|
|`_pegManager`|`address`|The address of the PegManager contract|


### _checkPegManager

*Throws if the sender is not the pegManager.*


```solidity
function _checkPegManager() internal view virtual;
```

### onlyPegManager


```solidity
modifier onlyPegManager();
```

