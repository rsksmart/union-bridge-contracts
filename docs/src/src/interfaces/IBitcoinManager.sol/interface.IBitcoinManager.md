# IBitcoinManager
[Git Source](https://github.com/rsksmart/union-bridge-contracts/blob/6c85aeb17a23ee9d675a92f8655a551ecca7b4c9/src/interfaces/IBitcoinManager.sol)

Interface for managing Bitcoin transaction operations in the union bridge

*This interface provides functions for generating addresses, validating transactions,*

*and calculating signature hashes for Bitcoin operations in the RSK union bridge*


## Functions
### getTemporaryPeginAddress

Obtains a temporary Bitcoin address for request peg-in operations

*Creates a Taproot address with committee and user key paths for secure peg-in*


```solidity
function getTemporaryPeginAddress(
    uint32 _timelockBlocks,
    address _rskDestinationAddress,
    uint64 _value,
    bytes32 _btcReimbursementPubKey,
    bytes memory _committeeTakePubKey
) external view returns (string memory temporaryPeginAddress);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_timelockBlocks`|`uint32`|The timelock blocks for the Bitcoin transaction|
|`_rskDestinationAddress`|`address`|The RSK address that will receive the RBTC|
|`_value`|`uint64`|The amount in satoshis to peg in (must match stream denomination)|
|`_btcReimbursementPubKey`|`bytes32`|The user's Bitcoin public key (x-coordinate only, 32 bytes)|
|`_committeeTakePubKey`|`bytes`|The committee's take aggregated public key|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`temporaryPeginAddress`|`string`|The generated temporary Bitcoin address for deposit|


### getPeginOpReturnData

Extracts data from a request peg-in Bitcoin transaction's OP_RETURN output

*Expected OP_RETURN format: [OP_RETURN][RSK_PEGIN][packet number][rsk destination address][btc reimbursement public key]*

*[OP_RETURN (1 byte)]*

*[OP_PUSHBYTES_69 (1 byte)]*

*[RSK_PEGIN (9 bytes)]*

*[packet number (8 bytes)]*

*[rsk destination address (20 bytes)]*

*[btc reimbursement public key (32 bytes)]*

*Total expected size: 71 bytes*

*This function parses the structured data embedded in the OP_RETURN output*


```solidity
function getPeginOpReturnData(BtcTxOut calldata _opReturnOut) external pure returns (uint64, address, bytes32);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_opReturnOut`|`BtcTxOut`|The Bitcoin transaction output containing OP_RETURN data|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint64`|packetNumber The packet number encoded in the OP_RETURN data|
|`<none>`|`address`|destinationAddress The RSK destination address encoded in the OP_RETURN data|
|`<none>`|`bytes32`|btcReimbursementPubKey The Bitcoin reimbursement public key (x only) encoded in the OP_RETURN data|


### validateRequestPeginP2TROutput

Validates a P2TR output for request peg-in transactions

*Ensures the Taproot output has the correct script structure with committee and user key paths*

*we don't check the inputs as this function is called by the pegin manager*


```solidity
function validateRequestPeginP2TROutput(
    uint32 _timelockBlocks,
    address _rskDestinationAddress,
    uint64 _streamDenomination,
    bytes32 _btcReimbursementPubKey,
    bytes memory _committeeTakePubKey,
    BtcTxOut calldata _p2trOut
) external pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_timelockBlocks`|`uint32`|The timelock blocks for the Bitcoin transaction|
|`_rskDestinationAddress`|`address`|The RSK address that should receive the RBTC|
|`_streamDenomination`|`uint64`|The expected amount in satoshis|
|`_btcReimbursementPubKey`|`bytes32`|The user's Bitcoin public key (x-coordinate only)|
|`_committeeTakePubKey`|`bytes`|The committee's take aggregated public key|
|`_p2trOut`|`BtcTxOut`|The Bitcoin transaction output to validate|


### validateRequestPeginEnablerOutput

Validates the enabler output in a request peg-in transaction

*We don't check the inputs as this function is called by the pegin manager that already validated the inputs*


```solidity
function validateRequestPeginEnablerOutput(bytes memory _expectedEnablerScriptPubKey, BtcTxOut calldata _enablerOut)
    external
    pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_expectedEnablerScriptPubKey`|`bytes`|The expected enabler script pub key (from packet storage)|
|`_enablerOut`|`BtcTxOut`|The enabler output to validate|


### getBtcTxid

Calculates the Bitcoin transaction id (txid) for a given transaction

*Encodes the transaction into Bitcoin's raw format and performs double SHA256 hash*

*This is the standard Bitcoin transaction ID used for referencing transactions*


```solidity
function getBtcTxid(BtcTransaction calldata _btcTx) external pure returns (bytes32);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_btcTx`|`BtcTransaction`|The Bitcoin transaction to hash|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|txid The transaction id in big-endian format (standard hex representation)|


### getAcceptPeginSignatureHash

Calculates the signature hash for Bitcoin accept peg-in transactions

*Generates the hash that committee members must sign to accept a peg-in*

*we don't check the inputs as this function is called by the pegin manager*


```solidity
function getAcceptPeginSignatureHash(
    bytes memory _committeeTakePubKey,
    bytes32 _userXOnlyPubKey,
    bytes32 _registerPeginTx,
    PrevoutData[] memory _prevoutDatas,
    CompactPubKey[] memory _disputeKeys
) external pure returns (BitcoinSignatureData memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_committeeTakePubKey`|`bytes`|The committee's take aggregated public key (x-coordinate only)|
|`_userXOnlyPubKey`|`bytes32`|The user's public key (x-coordinate only, 32 bytes)|
|`_registerPeginTx`|`bytes32`|The transaction id of the peg-in request being spent|
|`_prevoutDatas`|`PrevoutData[]`|Array of prevout data for all inputs being spent (taptree + enabler outputs)|
|`_disputeKeys`|`CompactPubKey[]`|The dispute keys for all members|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`BitcoinSignatureData`|BitcoinSignatureData containing txid, signatureHash, and signatureMessage|


### getEnablerOutputP2TRScriptPub

Generates the enabler output P2TR script pub key

*Creates a Taproot script for the enabler output with dispute keys in the merkle tree*


```solidity
function getEnablerOutputP2TRScriptPub(bytes memory _committeeTakePubKey, CompactPubKey[] memory _disputeKeys)
    external
    pure
    returns (bytes memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_committeeTakePubKey`|`bytes`|The committee's take aggregated public key (33 bytes compressed)|
|`_disputeKeys`|`CompactPubKey[]`|Array of dispute keys for committee members (parity byte + x-only 32 bytes)|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes`|The P2TR script pub key bytes|


### getSpeedUpScriptPub

Generates a P2WPKH script pub key for speed-up outputs

*Creates a P2WPKH script for Child Pays for Parent (CPFP) transactions to speed up the original transaction*

*Since user keys are x-only from OP_RETURN, parity is not available. So we will assume even Y-coordinate (0x02 prefix)*


```solidity
function getSpeedUpScriptPub(bytes32 _pubKey) external pure returns (bytes memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_pubKey`|`bytes32`|The user's x-only public key (32 bytes, from OP_RETURN)|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes`|The P2WPKH script pub key|


### validateSpeedUpOutput

Validates a speed-up output transactions

*Ensures the output is a valid P2WPKH for CPFP transactions to accelerate the parent transaction*


```solidity
function validateSpeedUpOutput(bytes32 _pubKey, BtcTxOut calldata _speedUpOut) external pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_pubKey`|`bytes32`|The user's public key (x-coordinate only, 32 bytes)|
|`_speedUpOut`|`BtcTxOut`|The Bitcoin transaction output containing the speed-up output|


### getPegoutTxData

Calculates the signature hash for Bitcoin peg-out transactions

*Generates the hash that committee members must sign to authorize a peg-out*


```solidity
function getPegoutTxData(bytes memory _userPubKey, bytes32 _acceptPeginTx, PrevoutData[] memory _prevoutDatas)
    external
    pure
    returns (BitcoinSignatureData memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_userPubKey`|`bytes`|The user's public key in compressed format that will receive the funds|
|`_acceptPeginTx`|`bytes32`|The transaction id of the accept peg-in tx being spent|
|`_prevoutDatas`|`PrevoutData[]`|Array of prevout data for all inputs being spent (taptree + enabler outputs)|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`BitcoinSignatureData`|BitcoinSignatureData containing txid, signatureHash, and signatureMessage|


### validatePegoutUserOutput

Validates that a peg-out transaction output is a P2WPKH paying the user

*Ensures the output correctly pays the user with the expected P2WPKH script*


```solidity
function validatePegoutUserOutput(BtcTxOut calldata _pegoutOutput, bytes memory _userPubKey) external pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_pegoutOutput`|`BtcTxOut`|The Bitcoin transaction output to validate|
|`_userPubKey`|`bytes`|The user's public key that should receive the funds|


### validatePegoutMemberOutput

Validates that a peg-out transaction output is a P2WPKH paying the committee member

*Ensures the output correctly pays the committee member with the expected P2WPKH script*


```solidity
function validatePegoutMemberOutput(BtcTxOut calldata _pegoutOutput, CompactPubKey calldata _memberPubKey)
    external
    pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_pegoutOutput`|`BtcTxOut`|The Bitcoin transaction output to validate|
|`_memberPubKey`|`CompactPubKey`|The committee member's public key that should receive the funds|


### validatePegoutIdOutput

Validates that a peg-out transaction output encodes the correct peg-out id in OP_RETURN

*Ensures the OP_RETURN output contains the expected peg-out id for tracking*


```solidity
function validatePegoutIdOutput(BtcTxOut calldata _pegoutIdOutput, bytes32 _pegoutId) external pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_pegoutIdOutput`|`BtcTxOut`|The Bitcoin transaction output containing OP_RETURN data|
|`_pegoutId`|`bytes32`|The expected peg-out id to validate against|


## Errors
### InvalidOpReturnLength
Thrown when OP_RETURN data length doesn't match expected format


```solidity
error InvalidOpReturnLength(uint256 actual, uint256 expected);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`actual`|`uint256`|The actual length of the OP_RETURN data|
|`expected`|`uint256`|The expected length of the OP_RETURN data|

### IncorrectlyFormedOpReturn
Thrown when OP_RETURN data is incorrectly formatted at a specific index


```solidity
error IncorrectlyFormedOpReturn(uint256 index);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`index`|`uint256`|The index where the formatting error occurred|

### IncorrectOutputScript
Thrown when a transaction output script doesn't match the expected format


```solidity
error IncorrectOutputScript(bytes actual, bytes expected);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`actual`|`bytes`|The actual script bytes found|
|`expected`|`bytes`|The expected script bytes|

### InvalidPublicKey
Thrown when a public key is invalid or malformed


```solidity
error InvalidPublicKey(bytes32 publicKey);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`publicKey`|`bytes32`|The invalid public key that was provided|

### InvalidTimelockBlocks
Thrown when a timelock blocks is invalid or zero


```solidity
error InvalidTimelockBlocks(uint32 timelockBlocks);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`timelockBlocks`|`uint32`|The invalid timelock blocks that was provided|

### InvalidCommitteePublicKeyLength
Error thrown when the committee public key has an invalid length


```solidity
error InvalidCommitteePublicKeyLength(uint256 length, uint256 expected);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`length`|`uint256`|The actual length provided|
|`expected`|`uint256`|The expected length (33 bytes)|

### InvalidCommitteePublicKeyZero
Error thrown when the committee public key is all zeros


```solidity
error InvalidCommitteePublicKeyZero();
```

### InvalidAddress
Thrown when an address is invalid or zero address


```solidity
error InvalidAddress(address _address);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_address`|`address`|The invalid address that was provided|

### InvalidValue
Thrown when a value doesn't match the expected amount


```solidity
error InvalidValue(uint64 _value, uint64 expected);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_value`|`uint64`|The actual value provided|
|`expected`|`uint64`|The expected value|

### InvalidInputAmount
Thrown when an input amount is invalid or zero


```solidity
error InvalidInputAmount(uint64 _value);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_value`|`uint64`|The invalid input amount|

### InvalidOutputAmount
Thrown when an output amount doesn't match the expected value


```solidity
error InvalidOutputAmount(uint64 actual, uint64 expected);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`actual`|`uint64`|The actual output amount|
|`expected`|`uint64`|The expected output amount|

