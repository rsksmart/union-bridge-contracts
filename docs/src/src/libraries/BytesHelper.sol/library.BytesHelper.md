# BytesHelper
[Git Source](https://github.com/temp-rsk/bitvmx-union-bridge-contracts/blob/4c35e62294ee16f56ba26d52283a5d84868fbd84/src/libraries/BytesHelper.sol)

Library for efficient bytes manipulation and conversion operations

*Provides utility functions for working with bytes arrays and converting between data types*

*Used throughout the union bridge for Bitcoin transaction data manipulation*

*Obtained from https://github.com/GNSPS/solidity-bytes-utils/blob/master/contracts/BytesLib.sol*


## State Variables
### ARRAY_SIZE

```solidity
uint8 constant ARRAY_SIZE = 8;
```


## Functions
### compare

Compares two bytes arrays for equality

*Uses keccak256 hash comparison for efficient equality checking*


```solidity
function compare(bytes memory a, bytes memory b) internal pure returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`a`|`bytes`|The first bytes array to compare|
|`b`|`bytes`|The second bytes array to compare|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|true if the arrays are equal, false otherwise|


### stringCompare

Compares two strings for equality

*Converts strings to bytes and uses the compare function*


```solidity
function stringCompare(string memory a, string memory b) internal pure returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`a`|`string`|The first string to compare|
|`b`|`string`|The second string to compare|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|true if the strings are equal, false otherwise|


### getBytesToString

Extracts a substring from bytes array

*Converts the specified bytes range to a string*


```solidity
function getBytesToString(bytes memory _bytes, uint256 _from, uint256 _length) internal pure returns (string memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_bytes`|`bytes`|The source bytes array|
|`_from`|`uint256`|The starting index (inclusive)|
|`_length`|`uint256`|The number of bytes to extract|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`string`|The extracted string|


### bytesToBytes32

Extracts a bytes32 value from a bytes array

*Reads 32 bytes starting from the specified index*


```solidity
function bytesToBytes32(bytes memory _bytes, uint256 _from) internal pure returns (bytes32);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_bytes`|`bytes`|The source bytes array|
|`_from`|`uint256`|The starting index|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|The extracted bytes32 value|


### bytesToAddress

Extracts an address value from a bytes array

*Reads 20 bytes starting from the specified index*


```solidity
function bytesToAddress(bytes memory _bytes, uint256 _from) internal pure returns (address);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_bytes`|`bytes`|The source bytes array|
|`_from`|`uint256`|The starting index|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The extracted address value|


### bytesToUint64

Extracts a uint64 value from a bytes array

*Reads 8 bytes starting from the specified index*


```solidity
function bytesToUint64(bytes memory _bytes, uint256 _from) internal pure returns (uint64);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_bytes`|`bytes`|The source bytes array|
|`_from`|`uint256`|The starting index|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint64`|The extracted uint64 value|


### bytesToUint32

Extracts a uint32 value from a bytes array

*Reads 4 bytes starting from the specified index*


```solidity
function bytesToUint32(bytes memory _bytes, uint256 _from) internal pure returns (uint32);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_bytes`|`bytes`|The source bytes array|
|`_from`|`uint256`|The starting index|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint32`|The extracted uint32 value|


### bytesToUint24

Extracts a uint24 value from a bytes array

*Reads 3 bytes starting from the specified index*


```solidity
function bytesToUint24(bytes memory _bytes, uint256 _from) internal pure returns (uint24);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_bytes`|`bytes`|The source bytes array|
|`_from`|`uint256`|The starting index|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint24`|The extracted uint24 value|


### bytesToUint16

Extracts a uint16 value from a bytes array

*Reads 2 bytes starting from the specified index*


```solidity
function bytesToUint16(bytes memory _bytes, uint256 _from) internal pure returns (uint16);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_bytes`|`bytes`|The source bytes array|
|`_from`|`uint256`|The starting index|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint16`|The extracted uint16 value|


### slice

Extracts a slice of bytes from a bytes array

*Creates a new bytes array containing the specified range*

*Uses assembly for efficient memory operations*


```solidity
function slice(bytes memory _bytes, uint256 _start, uint256 _length) internal pure returns (bytes memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_bytes`|`bytes`|The source bytes array|
|`_start`|`uint256`|The starting index (inclusive)|
|`_length`|`uint256`|The number of bytes to extract|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes`|The extracted bytes slice|


### isArrayEmpty


```solidity
function isArrayEmpty(bytes32[ARRAY_SIZE] memory _data) internal pure returns (bool);
```

## Errors
### indexOverflow
Error thrown when attempting to access bytes beyond the array bounds


```solidity
error indexOverflow(uint256 length, uint256 from, uint256 upTo);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`length`|`uint256`|The total length of the bytes array|
|`from`|`uint256`|The starting index of the access|
|`upTo`|`uint256`|The ending index of the access|

