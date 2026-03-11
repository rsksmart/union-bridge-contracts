# Bech32m
[Git Source](https://github.com/temp-rsk/bitvmx-union-bridge-contracts/blob/aa0c5b500b0a03f68164877ee0ab01eebfbdfa68/src/libraries/Bech32m.sol)

Library for Bech32m encoding and decoding used in Bitcoin Taproot addresses

*Implements the Bech32m checksum algorithm as specified in BIP-0350*

*Used for encoding Taproot addresses (P2TR) in the union bridge*


## State Variables
### CHARSET
*Character set for Bech32m encoding (32 characters)*

*Used to convert 5-bit values to human-readable characters*


```solidity
bytes constant CHARSET = "qpzry9x8gf2tvdw0s3jn54khce6mua7l";
```


### BECH32M_CONST
*Bech32m constant for checksum calculation*

*XORed with the polynomial modulo result to create the checksum*


```solidity
uint32 constant BECH32M_CONST = 0x2bc830a3;
```


### GENERATOR_0
*Generator constant 0 for polynomial modulo calculation*


```solidity
uint32 constant GENERATOR_0 = 0x3b6a57b2;
```


### GENERATOR_1
*Generator constant 1 for polynomial modulo calculation*


```solidity
uint32 constant GENERATOR_1 = 0x26508e6d;
```


### GENERATOR_2
*Generator constant 2 for polynomial modulo calculation*


```solidity
uint32 constant GENERATOR_2 = 0x1ea119fa;
```


### GENERATOR_3
*Generator constant 3 for polynomial modulo calculation*


```solidity
uint32 constant GENERATOR_3 = 0x3d4233dd;
```


### GENERATOR_4
*Generator constant 4 for polynomial modulo calculation*


```solidity
uint32 constant GENERATOR_4 = 0x2a1462b3;
```


## Functions
### bech32Polymod

Calculate the polynomial modulo for Bech32m checksum

*Implements the polynomial modulo algorithm used in Bech32m*


```solidity
function bech32Polymod(uint8[] memory values) internal pure returns (uint32);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`values`|`uint8[]`|Array of 5-bit values to process|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint32`|The polynomial modulo result|


### bech32HrpExpand

Expand the human-readable part (HRP) for checksum calculation

*Converts the HRP string into an array of 5-bit values*


```solidity
function bech32HrpExpand(string memory hrp) internal pure returns (uint8[] memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`hrp`|`string`|Human-readable part string (e.g., "bc", "tb", "bcrt")|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint8[]`|Array of 5-bit values representing the expanded HRP|


### convertBits

Convert data between different bit sizes

*Converts data from fromBits to toBits, with optional padding*


```solidity
function convertBits(bytes memory data, uint8 fromBits, uint8 toBits, bool pad)
    internal
    pure
    returns (uint8[] memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`data`|`bytes`|Input data to convert|
|`fromBits`|`uint8`|Source bit size|
|`toBits`|`uint8`|Target bit size|
|`pad`|`bool`|Whether to pad the output if necessary|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint8[]`|Array of converted data in the target bit size|


### bech32CreateChecksum

Create a Bech32m checksum for the given HRP and data

*Calculates the 6-character checksum using the Bech32m algorithm*


```solidity
function bech32CreateChecksum(string memory hrp, uint8[] memory data) internal pure returns (uint8[] memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`hrp`|`string`|Human-readable part string|
|`data`|`uint8[]`|Array of 5-bit data values|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint8[]`|Array of 6 checksum values|


### encodeTaprootAddress

Encode a Taproot public key as a Bech32m address

*Creates a P2TR (Pay-to-Taproot) address from a tweaked public key*


```solidity
function encodeTaprootAddress(bytes memory tweakedPubKey, BtcNetwork network) internal pure returns (string memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`tweakedPubKey`|`bytes`|The 32-byte tweaked public key|
|`network`|`BtcNetwork`|The Bitcoin network (mainnet, testnet, or regtest)|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`string`|The encoded Bech32m Taproot address|


## Errors
### InvalidNetwork
Error thrown when an invalid Bitcoin network is provided


```solidity
error InvalidNetwork(BtcNetwork network);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`network`|`BtcNetwork`|The invalid network value that was provided|

### InvalidPadding
Error thrown when invalid padding is detected during bit conversion

*Occurs when the padding flag is false but padding would be required*


```solidity
error InvalidPadding();
```

### InvalidBitsSize
Error thrown when a value exceeds the maximum allowed for the given bit size


```solidity
error InvalidBitsSize(uint256 value);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`value`|`uint256`|The value that exceeded the maximum allowed range|

### InvalidTweakedPublicKeyLength
Error thrown when a tweaked public key has an invalid length


```solidity
error InvalidTweakedPublicKeyLength(uint256 length, uint256 expected);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`length`|`uint256`|The actual length of the tweaked public key|
|`expected`|`uint256`|The expected length (32 bytes)|

