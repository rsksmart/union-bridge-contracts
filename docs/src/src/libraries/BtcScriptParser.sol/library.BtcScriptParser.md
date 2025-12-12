# BtcScriptParser
[Git Source](https://github.com/temp-rsk/bitvmx-union-bridge-contracts/blob/13960dd321557c932048de4fc7353af5ceae0b8d/src/libraries/BtcScriptParser.sol)

**Author:**
Fairgate

Library for encoding and decoding Bitcoin scripts

*Provides functions to create various Bitcoin script types and push data to the stack*

*Used for creating Bitcoin transaction scripts in the union bridge*


## State Variables
### MAX_BLOCK_TIMELOCK
*Maximum block timelock value allowed in scripts*

*Used to prevent excessive timelock values*


```solidity
uint256 constant MAX_BLOCK_TIMELOCK = 65535;
```


## Functions
### getP2WPKHScript

Creates a Pay-to-Witness-Public-Key-Hash (P2WPKH) script

*Creates a native SegWit script for spending to a public key hash*


```solidity
function getP2WPKHScript(bytes memory _userPubKey) internal pure returns (bytes memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_userPubKey`|`bytes`|The user's public key to hash|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes`|The P2WPKH script bytes|


### getP2WSHScript

Creates a Pay-to-Witness-Script-Hash (P2WSH) script

*Creates a native SegWit script for spending to a script hash*


```solidity
function getP2WSHScript(bytes memory _script) internal pure returns (bytes memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_script`|`bytes`|The script to hash|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes`|The P2WSH script bytes|


### pushNumberToStack

Pushes a number onto the Bitcoin script stack

*Handles different number ranges with appropriate opcodes and encoding*

*Uses minimal encoding for numbers to optimize script size*


```solidity
function pushNumberToStack(uint256 _number) internal pure returns (bytes memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_number`|`uint256`|The number to push onto the stack|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes`|The script bytes for pushing the number|


### getTimelockScript

Creates a timelock script with OP_CHECKSEQUENCEVERIFY

*If the specified number of blocks have passed since transaction confirmation,*

*the timelocked public key can spend the funds*


```solidity
function getTimelockScript(uint32 _blocks, bytes32 _publicKey) internal pure returns (bytes memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_blocks`|`uint32`|The number of blocks to wait before the script can be spent|
|`_publicKey`|`bytes32`|The 32-byte x-coordinate of the public key (Taproot format)|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes`|The timelock script bytes|


## Errors
### NumberTooLarge
Error thrown when a number exceeds the maximum allowed value


```solidity
error NumberTooLarge(uint256 actual, uint256 max);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`actual`|`uint256`|The actual number value that was too large|
|`max`|`uint256`|The maximum allowed value|

