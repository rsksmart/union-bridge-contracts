# IAccessControl
[Git Source](https://github.com/FairgateLabs/bitvmx-union-bridge-contracts/blob/b91181b0a4bd785ef0099b4b80f38101dfa816d0/src/interfaces/IAccessControl.sol)

Interface for access control in the union bridge

*This interface provides error definitions for access control operations*

*Used to ensure proper authorization for sensitive operations*


## Errors
### PegManagerAddressZero
Thrown when the Peg Manager address is set to zero


```solidity
error PegManagerAddressZero();
```

### UnauthorizedAccount
Thrown when an account is not authorized to perform an operation


```solidity
error UnauthorizedAccount(address sender);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`sender`|`address`|The address of the unauthorized account|

