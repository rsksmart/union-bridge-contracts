# IMusig2
[Git Source](https://github.com/rsksmart/union-bridge-contracts/blob/6c85aeb17a23ee9d675a92f8655a551ecca7b4c9/src/interfaces/IMusig2.sol)

Interface for pauser in the union bridge

*This interface provides error definitions for pauser operations*

*Used to implement open zeppelin's pauser functionality*


## Functions
### isValidPubKey

Checks if a public key is valid


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


## Errors
### InvalidNoncesLength
Thrown when the nonces length is invalid


```solidity
error InvalidNoncesLength(uint256 length, uint256 pubKeysLength);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`length`|`uint256`|The actual length of the nonces|
|`pubKeysLength`|`uint256`|The actual length of the public keys|

### InvalidPubKeyIndex
Thrown when the public key index is invalid


```solidity
error InvalidPubKeyIndex(uint256 index, uint256 pubKeysLength);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`index`|`uint256`|The actual index of the public key|
|`pubKeysLength`|`uint256`|The actual length of the public keys|

### InvalidParticipantsLength
Thrown when the participants length is invalid


```solidity
error InvalidParticipantsLength(uint256 length, uint256 minLength);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`length`|`uint256`|The actual length of the participants|
|`minLength`|`uint256`|The minimum length expected|

### AllPubkeysAreTheSame
Thrown when all public keys are the same


```solidity
error AllPubkeysAreTheSame();
```

### EcAddPrecompileFailed
Thrown when the ec add precompile failed


```solidity
error EcAddPrecompileFailed();
```

### EcMulPrecompileFailed
Thrown when the ec mul precompile failed


```solidity
error EcMulPrecompileFailed();
```

### InvalidPartialSignature
Thrown when the partial signature is invalid


```solidity
error InvalidPartialSignature();
```

### InvalidMessage
Thrown when the message is invalid


```solidity
error InvalidMessage();
```

