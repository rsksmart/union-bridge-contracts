# AccessControl
[Git Source](https://github.com/temp-rsk/bitvmx-union-bridge-contracts/blob/96535706e496364789ce242b18e17052bb6e424e/src/AccessControl.sol)

**Inherits:**
[IAccessControl](/src/interfaces/IAccessControl.sol/interface.IAccessControl.md), [BaseProxy](/src/BaseProxy.sol/abstract.BaseProxy.md)

Manages access control for the union bridge system

*Provides role-based access control with PeginManager and PegoutManager as the primary authorized accounts*

*Inherits from IAccessControl and BaseProxy for interface compliance and proxy functionality*


## State Variables
### peginManager
The address of the PeginManager contract that has administrative privileges

*This address is authorized to call protected functions in contracts that inherit from AccessControl*


```solidity
address public peginManager;
```


### pegoutManager
The address of the PegoutManager contract that has administrative privileges

*This address is authorized to call protected functions in contracts that inherit from AccessControl*


```solidity
address public pegoutManager;
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

*Sets up the initial owner and PeginManager/PegoutManager addresses*

*Can only be called once during contract deployment*


```solidity
function __AccessControl_init(address _initialOwner, address _peginManager, address _pegoutManager)
    public
    initializer;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_initialOwner`|`address`|The address that will be set as the initial owner|
|`_peginManager`|`address`|The address of the PeginManager contract|
|`_pegoutManager`|`address`|The address of the PegoutManager contract|


### __AccessControl_init_without_peg_managers

Initializes the AccessControl contract with delayed peg manager setup

*Used when peg managers need to be set after deployment via setters*

*Can only be called once during contract deployment*


```solidity
function __AccessControl_init_without_peg_managers(address _initialOwner) internal initializer;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_initialOwner`|`address`|The address that will be set as the initial owner|


### onlyPegManager


```solidity
modifier onlyPegManager();
```

### _checkPegManager

*Reverts if the sender is neither the peginManager nor the pegoutManager*


```solidity
function _checkPegManager() internal view virtual;
```

