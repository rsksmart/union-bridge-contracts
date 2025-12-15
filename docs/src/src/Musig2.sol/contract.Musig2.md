# Musig2
[Git Source](https://github.com/temp-rsk/bitvmx-union-bridge-contracts/blob/96535706e496364789ce242b18e17052bb6e424e/src/Musig2.sol)

**Inherits:**
[IMusig2](/src/interfaces/IMusig2.sol/interface.IMusig2.md)

**Author:**
The Fairgate Team

Contract for verifying Musig2 signatures

*MuSig2 is a two-round multi-signature scheme that allows multiple parties to jointly produce a single Schnorr signature. It provides better privacy and efficiency compared to script-based multi-signatures, as the aggregated signature is indistinguishable from a single-party signature.*

*MuSig2 allows groups of mutually distrusting parties to cooperatively sign data and aggregate their signatures into a single aggregated signature which is indistinguishable from a signature made by a single private key. The group collectively controls an aggregated public key which can only create signatures if everyone in the group cooperates (AKA an N-of-N multisignature scheme). MuSig2 is optimized to support secure signature aggregation with only two round-trips of network communication.*

*Specifically, this library [implements BIP-0327](https://en.bitcoin.it/wiki/BIP_0327), for creating and verifying signatures which validate under Bitcoin consensus rules, but the protocol is flexible and can be applied to any N-of-N multisignature use-case.*

*The process of cooperative signing runs like so:*

*1. All signers share their public keys with one-another. The group computes an aggregated public key which they collectively control.*

*2. In the first signing round, signers generate and share nonces (random numbers) with one-another. These nonces have both secret and public versions. Only the public nonce (AKA PubNonce) should be shared, while the corresponding secret nonce (AKA SecNonce) must be kept secret.*

*3. Once every signer has received the public nonces of every other signer, each signer makes a partial signature for a message using their secret key and secret nonce.*

*4. In the second signing round, signers share their partial signatures with one-another. Partial signatures can be verified to place blame on misbehaving signers (but are not themselves unforgeable).*

*5. A valid set of partial signatures can be aggregated into a final signature, which is just a normal Schnorr signature, valid under the aggregated public key.*

*This Contract uses the secp256k1 precompiled contracts from the RSKJ implementation.*

*Following RSKIP-516: https://github.com/rsksmart/RSKIPs/blob/master/IPs/RSKIP516.md*

*code: https://github.com/rsksmart/rskj/pull/3210/files#diff-6449788dd39d9278472df8fb3a946ef83b7d16c8452a90cc6e2a238f6615e8bf*


## State Variables
### KEYAGG_LIST
KeyAgg list for MuSig2


```solidity
bytes constant KEYAGG_LIST = bytes("KeyAgg list");
```


### KEYAGG_COEFFICIENT
KeyAgg coefficient for MuSig2


```solidity
bytes constant KEYAGG_COEFFICIENT = bytes("KeyAgg coefficient");
```


### MUSIG_NONCECOEF
Nonce coefficient for MuSig2


```solidity
bytes constant MUSIG_NONCECOEF = bytes("MuSig/noncecoef");
```


### BIP0340_CHALLENGE
Challenge for BIP0340


```solidity
bytes constant BIP0340_CHALLENGE = bytes("BIP0340/challenge");
```


### SECP256K1_ADDITION_ADDR
Addresses of the secp256k1 multiplication Rskj precompiled contracts

*Following RSKIP-516: https://github.com/rsksmart/RSKIPs/blob/master/IPs/RSKIP516.md*

*code: https://github.com/rsksmart/rskj/pull/3210/files#diff-6449788dd39d9278472df8fb3a946ef83b7d16c8452a90cc6e2a238f6615e8bf*


```solidity
address constant SECP256K1_ADDITION_ADDR = address(0x0000000000000000000000000000000001000016);
```


### SECP256K1_MULTIPLICATION_ADDR
*Following RSKIP-516: https://github.com/rsksmart/RSKIPs/blob/master/IPs/RSKIP516.md*

*code: https://github.com/rsksmart/rskj/pull/3210/files#diff-6449788dd39d9278472df8fb3a946ef83b7d16c8452a90cc6e2a238f6615e8bf*


```solidity
address constant SECP256K1_MULTIPLICATION_ADDR = address(0x0000000000000000000000000000000001000017);
```


## Functions
### isValidPubKey

Check if a public key is valid


```solidity
function isValidPubKey(Point memory pubKey) external pure returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`pubKey`|`Point`|The public key to check|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|true if the public key is valid, false otherwise|


### verifyPartialSignature

Verify a partial signature for a given public key index

*This function expects the public keys to be in the same order and have the same length as the nonces.*

*This function expects the public keys and nonces to be already validated.*

*We are following the specification BIP-327: MuSig2 for BIP340-compatible Multi-Signatures https://github.com/bitcoin/bips/blob/master/bip-0327.mediawiki.*

*We check for correctnes of the implementation against the rust musgi2 implementation: https://github.com/FairgateLabs/rust-bitvmx-key-manager/pull/48*

*The implementation uses the RSKJ Secp256k1 precompiled contract: https://github.com/rsksmart/rskj/pull/3210/files#diff-6449788dd39d9278472df8fb3a946ef83b7d16c8452a90cc6e2a238f6615e8bf*

*The specification can be found in RSKIP-516: https://github.com/rsksmart/RSKIPs/blob/master/IPs/RSKIP516.md.*


```solidity
function verifyPartialSignature(
    uint256 _partialSignature,
    uint256 _pubKeyIndex,
    Point[] memory _participantsPubKeys,
    Nonce[] memory _nonces,
    bytes memory _message
) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_partialSignature`|`uint256`|The partial signature|
|`_pubKeyIndex`|`uint256`|The index of the public key to verify|
|`_participantsPubKeys`|`Point[]`|The list of public keys to aggregate|
|`_nonces`|`Nonce[]`|The list of nonces|
|`_message`|`bytes`|The message to sign|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|true if the partial signature is valid, false otherwise|


### _aggregatedAndEffectivePubKey

Calculate an aggregated public key from a list of public keys


```solidity
function _aggregatedAndEffectivePubKey(Point[] memory _participantsPubKeys, uint256 _pubKeyIndex)
    internal
    view
    returns (Point memory aggregatedPubKey, Point memory individualEffectivePubkey);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_participantsPubKeys`|`Point[]`|The list of public keys to aggregate|
|`_pubKeyIndex`|`uint256`||

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`aggregatedPubKey`|`Point`|The aggregated public key|
|`individualEffectivePubkey`|`Point`|The individual effective public key|


### _effectiveNonce


```solidity
function _effectiveNonce(Nonce memory _individualPubNonce, uint256 _nonceCoef, Point memory _adaptedAggregatedNonce)
    internal
    view
    returns (Point memory effectiveNonce);
```

### _challengePoint


```solidity
function _challengePoint(
    Point memory _adaptedAggregatedNonce,
    Point memory _effectivePubkey,
    Point memory _aggregatedPubKey,
    bytes memory _message
) internal view returns (Point memory challengePoint);
```

### _verifyChallenge


```solidity
function _verifyChallenge(
    uint256 _partialSignature,
    Point memory _individualEffectiveNonce,
    Point memory _aggregatedChallengePoint
) internal view returns (bool);
```

### _aggregatedNonce

Calculate the adapted aggregated nonce


```solidity
function _aggregatedNonce(uint256 xOnlyAggregatedPubKey, Nonce[] memory _nonces, bytes memory _message)
    internal
    view
    returns (Point memory adaptedAggregatedNonce, uint256 nonceCoef);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`xOnlyAggregatedPubKey`|`uint256`|The x-only aggregated public key|
|`_nonces`|`Nonce[]`|The list of nonces|
|`_message`|`bytes`|The message to sign|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`adaptedAggregatedNonce`|`Point`|The adapted aggregated nonce|
|`nonceCoef`|`uint256`|The nonce coefficient|


### _equalCompressedPubKeys

Compare two compressed public keys for equality


```solidity
function _equalCompressedPubKeys(bytes memory a, bytes memory b) internal pure returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`a`|`bytes`|The first compressed public key|
|`b`|`bytes`|The second compressed public key|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|true if the compressed public keys are equal, false otherwiseß|


### _reduceToScalar

Reduce a hash to a scalar that exists in the secp256k1 curve


```solidity
function _reduceToScalar(bytes32 _hash) internal pure returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_hash`|`bytes32`|The hash to reduce|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|scalar The reduced scalar|


### _isLessThan

Compare two public keys in lexicographic order


```solidity
function _isLessThan(Point memory a, Point memory b) internal pure returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`a`|`Point`|The first public key|
|`b`|`Point`|The second public key|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|true if a is less than b, false otherwise|


### _toCompressPubKey

Compress a public key to a 33-byte compressed format


```solidity
function _toCompressPubKey(Point memory pubKey) internal pure returns (bytes memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`pubKey`|`Point`|The public key to compress|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes`|compressedPubKey The compressed public key in 0x02/0x03 + x format|


### _insertionSort

Sorts the array of points in-place (ascending)

*Uses insertion sort (O(n²)), best for small arrays (<100 elements)*


```solidity
function _insertionSort(Point[] memory points) internal pure returns (Point[] memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`points`|`Point[]`|The array of points to sort|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`Point[]`|points The sorted array of points|


### _ecMul

Call ecMul precompile: input (x,y,scalar) -> returns (x',y')

*rskj-core/src/test/resources/dsl/ec_precompiled_contracts/secp256k1_multiplication.txt*

*https://github.com/rsksmart/rskj/pull/3210/files#diff-1361f673170f1b7be5d13469bfe16cdf0b1548c3a09416c8b071a49ad8704b46R16*


```solidity
function _ecMul(uint256 x, uint256 y, uint256 scalar) internal view virtual returns (uint256 rx, uint256 ry);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`x`|`uint256`|The x-coordinate of the point|
|`y`|`uint256`|The y-coordinate of the point|
|`scalar`|`uint256`|The scalar to multiply by|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`rx`|`uint256`|The x-coordinate of the result|
|`ry`|`uint256`|The y-coordinate of the result|


### _ecAdd

Call ecAdd precompile: input (x1,y1,x2,y2) -> returns (x3,y3)

*rskj-core/src/test/resources/dsl/ec_precompiled_contracts/secp256k1_addition.txt*

*https://github.com/rsksmart/rskj/pull/3210/files#diff-98501e625b566e9397c6eba238c2e7b34decae13b6ddba8645792740bed3665cR17*


```solidity
function _ecAdd(uint256 x1, uint256 y1, uint256 x2, uint256 y2)
    internal
    view
    virtual
    returns (uint256 rx, uint256 ry);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`x1`|`uint256`|The x-coordinate of the first point|
|`y1`|`uint256`|The y-coordinate of the first point|
|`x2`|`uint256`|The x-coordinate of the second point|
|`y2`|`uint256`|The y-coordinate of the second point|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`rx`|`uint256`|The x-coordinate of the result|
|`ry`|`uint256`|The y-coordinate of the result|


### _secp256k1AssemblyCall

Call a precompile secp256k1 contract using assembly calls


```solidity
function _secp256k1AssemblyCall(address addr, bytes memory data) internal view returns (uint256 x, uint256 y);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`addr`|`address`|The address of the precompile contract to call|
|`data`|`bytes`|The data to send to the precompile contract|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`x`|`uint256`|The x-coordinate of the result|
|`y`|`uint256`|The y-coordinate of the result|


