# BtcTxEncoder
[Git Source](https://github.com/temp-rsk/bitvmx-union-bridge-contracts/blob/2c7f90ba21d83a98b646123c60d27a00fe0644fd/src/libraries/BtcTxEncoder.sol)

**Author:**
Fairgate

Library for encoding and decoding Bitcoin transaction data

*Provides functions to convert Bitcoin transaction structures to raw hex format*

*Used for creating and validating Bitcoin transactions in the union bridge*


## Functions
### encodeInputsOutpoints

Encodes input outpoints (txId and vout) in Bitcoin format

*Converts txId and vout to little endian format for Bitcoin compatibility*


```solidity
function encodeInputsOutpoints(bytes32 _txId, uint32 _vout) internal pure returns (bytes memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_txId`|`bytes32`|The transaction ID to encode|
|`_vout`|`uint32`|The output index to encode|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes`|The encoded outpoint bytes|


### encodeSequence

Encodes sequence number in Bitcoin format

*Converts sequence to little endian format for Bitcoin compatibility*

*See: https://learnmeabitcoin.com/technical/transaction/#structure-input-count*


```solidity
function encodeSequence(uint32 _sequence) internal pure returns (uint32);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_sequence`|`uint32`|The sequence number to encode|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint32`|The encoded sequence in little endian|


### encodeScript

Encodes a script with its compact size prefix

*Prepends the script length in compact size format to the script data*

*See: https://learnmeabitcoin.com/technical/transaction/#structure-input-count*


```solidity
function encodeScript(bytes memory _script) internal pure returns (bytes memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_script`|`bytes`|The script to encode|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes`|The encoded script with size prefix|


### encodeTxIn

Encodes a complete transaction input in Bitcoin format

*Combines outpoint, scriptSig, and sequence into a single input structure*

*See: https://learnmeabitcoin.com/technical/transaction/#structure-input-count*


```solidity
function encodeTxIn(bytes32 _txId, uint32 _vout, uint32 _sequence, bytes memory _scriptSig)
    internal
    pure
    returns (bytes memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_txId`|`bytes32`|The transaction ID of the input being spent|
|`_vout`|`uint32`|The output index being spent|
|`_sequence`|`uint32`|The sequence number for the input|
|`_scriptSig`|`bytes`|The script signature (empty for non-legacy transactions)|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes`|The encoded transaction input|


### encodeTxInputs

Converts an array of Bitcoin transaction inputs to raw hex format

*Encodes all inputs with their count in compact size format*

*Format: [inputs count][txid0][vout0][script sig size 0][script sig 0][sequence0]...*


```solidity
function encodeTxInputs(BtcTxIn[] memory _inputs) internal pure returns (bytes memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_inputs`|`BtcTxIn[]`|Array of transaction inputs to encode|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes`|The encoded transaction inputs|


### encodeAmount

Encodes amount in Bitcoin format (little endian)

*Converts amount to little endian format for Bitcoin compatibility*


```solidity
function encodeAmount(uint64 _amount) internal pure returns (uint64);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_amount`|`uint64`|The amount in satoshis to encode|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint64`|The encoded amount in little endian|


### encodeTxOut

Encodes a complete transaction output in Bitcoin format

*Combines amount and scriptPubKey into a single output structure*

*See: https://learnmeabitcoin.com/technical/transaction/#structure-outputs*


```solidity
function encodeTxOut(uint64 _amount, bytes memory _scriptPubKey) internal pure returns (bytes memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_amount`|`uint64`|The output amount in satoshis|
|`_scriptPubKey`|`bytes`|The script that locks the output|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes`|The encoded transaction output|


### encodeTxOutputs

Converts an array of transaction outputs to raw hex format

*Encodes all outputs with their count in compact size format*

*Format: [output count][amount0][script pubkey size 0][script pubkey 0]...*


```solidity
function encodeTxOutputs(BtcTxOut[] memory _outputs) internal pure returns (bytes memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_outputs`|`BtcTxOut[]`|Array of transaction outputs to encode|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes`|The encoded transaction outputs|


### encodeLocktime

Encodes locktime in Bitcoin format (little endian)

*Converts locktime to little endian format for Bitcoin compatibility*


```solidity
function encodeLocktime(uint32 _locktime) internal pure returns (uint32);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_locktime`|`uint32`|The locktime value to encode|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint32`|The encoded locktime in little endian|


### encodeVersion

Encodes version in Bitcoin format (little endian)

*Converts version to little endian format for Bitcoin compatibility*


```solidity
function encodeVersion(uint32 _version) internal pure returns (uint32);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_version`|`uint32`|The version number to encode|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint32`|The encoded version in little endian|


### encodeTx

Converts a complete Bitcoin transaction to raw hex format

*Encodes the entire transaction structure for hash calculation*

*Format: [version][inputs][outputs][locktime]*

*See: https://learnmeabitcoin.com/technical/transaction/#structure*


```solidity
function encodeTx(BtcTransaction memory _btcTx) internal pure returns (bytes memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_btcTx`|`BtcTransaction`|The Bitcoin transaction to encode|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes`|The encoded transaction in raw hex format|


### encodeCommonSignatureMessage

Creates the common signature message for Taproot transaction signing

*Implements the Taproot signature message format as specified in BIP-341*

*See: https://learnmeabitcoin.com/technical/upgrades/taproot/#common-signature-message*


```solidity
function encodeCommonSignatureMessage(uint8 _hashType, PrevoutData[] memory prevoutDatas, BtcTransaction memory btcTx)
    internal
    pure
    returns (bytes memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_hashType`|`uint8`|The hash type for the signature|
|`prevoutDatas`|`PrevoutData[]`|Array of previous output data for all inputs|
|`btcTx`|`BtcTransaction`|The Bitcoin transaction being signed|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes`|The common signature message bytes|


### getInputsShaForSignature

Calculates SHA256 hashes for all input data needed in signature message

*Creates four separate hashes for prevouts, amounts, scriptPubKeys, and sequences*


```solidity
function getInputsShaForSignature(PrevoutData[] memory prevoutDatas, BtcTxIn[] memory btcTxIns)
    internal
    pure
    returns (bytes32, bytes32, bytes32, bytes32);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`prevoutDatas`|`PrevoutData[]`|Array of previous output data|
|`btcTxIns`|`BtcTxIn[]`|Array of transaction inputs|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|sha_prevouts SHA256 of all input outpoints|
|`<none>`|`bytes32`|sha_amounts SHA256 of all input amounts|
|`<none>`|`bytes32`|sha_scriptPubKeys SHA256 of all spent output scriptPubKeys|
|`<none>`|`bytes32`|sha_sequences SHA256 of all input sequences|


### getOutputsShaForSignature

Calculates SHA256 hash of all transaction outputs for signature message

*Creates a single hash of all outputs in CTxOut format*


```solidity
function getOutputsShaForSignature(BtcTxOut[] memory btcTxOuts) internal pure returns (bytes32);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`btcTxOuts`|`BtcTxOut[]`|Array of transaction outputs|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|sha_outputs SHA256 of all outputs in CTxOut format|


## Errors
### InvalidPrevoutDataLength
Error thrown when prevout data length doesn't match transaction input length


```solidity
error InvalidPrevoutDataLength(uint256 actual, uint256 expected);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`actual`|`uint256`|The actual length of prevout data array|
|`expected`|`uint256`|The expected length (should match transaction input count)|

