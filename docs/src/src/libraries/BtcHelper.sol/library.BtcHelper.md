# BtcHelper
[Git Source](https://github.com/temp-rsk/bitvmx-union-bridge-contracts/blob/96535706e496364789ce242b18e17052bb6e424e/src/libraries/BtcHelper.sol)

**Author:**
Fairgate

Usefull functions for Bitcoin parsin/encoding/decoding


## Functions
### toCompactSize

Converts a size value to Bitcoin's compact size format

*The first byte indicates which bytes encode the integer:*

*<= FC – This byte (0 - 252)*

*FD – The next two bytes (253 - 65535)*

*FE – The next four bytes (65536 - 4294967295)*

*FF – The next eight bytes (4294967296 - 18446744073709551615)*

*Note: Bytes encoding the integer are in little endian*

*See: https://learnmeabitcoin.com/technical/general/compact-_size/*


```solidity
function toCompactSize(uint256 _size) internal pure returns (bytes memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_size`|`uint256`|The size value to convert|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes`|The compact size encoded bytes|


### hash160

Implements Bitcoin's hash160 (RIPEMD160(SHA256()))

*abi.encodePacked changes the return to bytes instead of bytes32*

*Used for creating Bitcoin addresses from public keys*

*See: https://github.com/bob-collective/bitcoin-spv/blob/master/src/BTCUtils.sol#L192C5-L198C6*


```solidity
function hash160(bytes memory _b) internal pure returns (bytes20);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_b`|`bytes`|The pre-image to hash|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes20`|The RIPEMD160(SHA256()) digest|


### hash256

Implements Bitcoin's double SHA256 hash with endianness correction

*This is how Bitcoin calls double SHA256 and we reverse it to correct endian*

*Converts from little endian (used by Bitcoin) to big endian (used by humans)*

*See: https://learnmeabitcoin.com/technical/general/byte-order/*


```solidity
function hash256(bytes memory _toHash) internal pure returns (bytes32);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_toHash`|`bytes`|The data to hash|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|The double SHA256 hash in big endian format|


### reverseBytes32

Reverses the byte order of a bytes32 value

*Used to convert between little endian (used by Bitcoin) and big endian (used by humans)*

*See: https://ethereum.stackexchange.com/questions/83626/how-to-reverse-byte-order-in-uint256-or-bytes32#answer-83627*


```solidity
function reverseBytes32(bytes32 _input) internal pure returns (bytes32 v);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_input`|`bytes32`|The bytes32 value to reverse|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`v`|`bytes32`|The reversed bytes32 value|


### reverseUint64

Changes the endianness of a uint64

*Converts between little endian (used by Bitcoin) and big endian (used by humans)*

*See: https://github.com/bob-collective/bitcoin-spv/blob/master/src/BTCUtils.sol#L127*


```solidity
function reverseUint64(uint64 _b) internal pure returns (uint64 v);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_b`|`uint64`|The unsigned integer to reverse|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`v`|`uint64`|The reversed value|


### reverseUint32

Changes the endianness of a uint32

*Converts between little endian (used by Bitcoin) and big endian (used by humans)*

*See: https://github.com/bob-collective/bitcoin-spv/blob/master/src/BTCUtils.sol#L143*


```solidity
function reverseUint32(uint32 _b) internal pure returns (uint32 v);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_b`|`uint32`|The unsigned integer to reverse|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`v`|`uint32`|The reversed value|


### reverseUint24

Changes the endianness of a uint24

*Converts between little endian (used by Bitcoin) and big endian (used by humans)*


```solidity
function reverseUint24(uint24 _b) internal pure returns (uint24 v);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_b`|`uint24`|The unsigned integer to reverse|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`v`|`uint24`|The reversed value|


### reverseUint16

Changes the endianness of a uint16

*Converts between little endian (used by Bitcoin) and big endian (used by humans)*

*See: https://github.com/bob-collective/bitcoin-spv/blob/master/src/BTCUtils.sol#L163*


```solidity
function reverseUint16(uint16 _b) internal pure returns (uint16 v);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_b`|`uint16`|The unsigned integer to reverse|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`v`|`uint16`|The reversed value|


### calculateFeeAndSpeedUp

Calculate fee and speed-up amounts for Bitcoin transactions

*TODO: calculate fee and speed up properly from the amount*

*Currently returns fixed values from Constants*


```solidity
function calculateFeeAndSpeedUp() internal pure returns (uint64, uint64);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint64`|The fee amount in satoshis|
|`<none>`|`uint64`|The speed-up amount in satoshis|


### weiToSatoshi

Convert wei amount to satoshis

*Divides by 10^10 to convert from wei used in RSK to satoshis used in Bitcoin*


```solidity
function weiToSatoshi(uint256 _amount) internal pure returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_amount`|`uint256`|The amount in wei|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The amount in satoshis|


### satoshiToWei

Convert satoshis to wei amount

*Multiplies by 10^10 to convert from satoshis used in Bitcoin to wei used in RSK*


```solidity
function satoshiToWei(uint256 _amount) internal pure returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_amount`|`uint256`|The amount in satoshis|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The amount in wei|


### pubKeyXonlyToCompact

Converts a bytes32 public key to a bytes format

*The public key is expected to be in the compressed format (x-coordinate only)*

*The first byte is set to 0x02 to indicate a compressed public key*


```solidity
function pubKeyXonlyToCompact(bytes32 _pubKey) internal pure returns (bytes memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_pubKey`|`bytes32`|The public key in bytes32 format|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes`|The public key in bytes format|


