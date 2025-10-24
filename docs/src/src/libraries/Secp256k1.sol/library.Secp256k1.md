# Secp256k1
[Git Source](https://github.com/FairgateLabs/bitvmx-union-bridge-contracts/blob/3db9056f26f2b3b61c05819d9eb725e59c32f233/src/libraries/Secp256k1.sol)

**Author:**
Witnet Foundation

Library for secp256k1 elliptic curve operations used in Bitcoin cryptography

*Particularization of Elliptic Curve for secp256k1 curve parameters*

*Used for Bitcoin public key operations and signature verification*


## State Variables
### GX
*Generator point x-coordinate for secp256k1 curve*

*Base point G used for public key generation*


```solidity
uint256 public constant GX = 0x79BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F81798;
```


### GY
*Generator point y-coordinate for secp256k1 curve*

*Base point G used for public key generation*


```solidity
uint256 public constant GY = 0x483ADA7726A3C4655DA4FBFC0E1108A8FD17B448A68554199C47D08FFB10D4B8;
```


### AA
*Coefficient 'a' in the secp256k1 curve equation y² = x³ + ax + b*

*For secp256k1, a = 0*


```solidity
uint256 public constant AA = 0;
```


### BB
*Coefficient 'b' in the secp256k1 curve equation y² = x³ + ax + b*

*For secp256k1, b = 7*


```solidity
uint256 public constant BB = 7;
```


### PP
*Prime field modulus for secp256k1 curve*

*Defines the finite field over which the curve is defined*


```solidity
uint256 public constant PP = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F;
```


## Functions
### deriveY

Derives the y coordinate from a compressed-format point x

*Implements the algorithm from [SEC-1](https://www.secg.org/SEC1-Ver-1.0.pdf)*


```solidity
function deriveY(uint8 _prefix, uint256 _x) internal pure returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_prefix`|`uint8`|Parity byte (0x02 for even y, 0x03 for odd y)|
|`_x`|`uint256`|X coordinate of the point|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|y Y coordinate of the point|


### isOnCurve

Check whether point (x,y) is on the secp256k1 curve

*Verifies that the point satisfies the curve equation y² = x³ + 7*


```solidity
function isOnCurve(uint256 _x, uint256 _y) internal pure returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_x`|`uint256`|X coordinate of the point to check|
|`_y`|`uint256`|Y coordinate of the point to check|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|true if the point is on the curve, false otherwise|


### ecAdd

Add two points (x1, y1) and (x2, y2) in affine coordinates

*Performs elliptic curve point addition: P1 + P2*


```solidity
function ecAdd(uint256 _x1, uint256 _y1, uint256 _x2, uint256 _y2) internal pure returns (uint256, uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_x1`|`uint256`|X coordinate of the first point P1|
|`_y1`|`uint256`|Y coordinate of the first point P1|
|`_x2`|`uint256`|X coordinate of the second point P2|
|`_y2`|`uint256`|Y coordinate of the second point P2|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|(qx, qy) Result of P1 + P2 in affine coordinates|
|`<none>`|`uint256`||


### ecMul

Multiply point (x1, y1) by scalar k in affine coordinates

*Performs scalar multiplication: k * P*


```solidity
function ecMul(uint256 _k, uint256 _x, uint256 _y) internal pure returns (uint256, uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_k`|`uint256`|Scalar to multiply the point by|
|`_x`|`uint256`|X coordinate of the point P|
|`_y`|`uint256`|Y coordinate of the point P|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|(qx, qy) Result of k * P in affine coordinates|
|`<none>`|`uint256`||


