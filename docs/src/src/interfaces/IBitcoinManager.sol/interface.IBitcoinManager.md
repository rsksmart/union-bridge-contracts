# IBitcoinManager
[Git Source](https://github.com/FairgateLabs/bitvmx-union-bridge-contracts/blob/b750ea532307d08987643fe249271c69c1bee159/src/interfaces/IBitcoinManager.sol)

Interface for managing Bitcoin transaction operations in the union bridge

*This interface provides functions for generating addresses, validating transactions,*

*and calculating signature hashes for Bitcoin operations in the RSK union bridge*


## Functions
### getTemporaryPeginAddress

Obtains a temporary Bitcoin address for request peg-in operations

*Creates a Taproot address with committee and user key paths for secure peg-in*


```solidity
function getTemporaryPeginAddress(
    address _rskDestinationAddress,
    uint64 _value,
    bytes32 _btcReimbursementPubKey,
    bytes32 _committeePubKey
) external view returns (string memory temporaryPeginAddress);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_rskDestinationAddress`|`address`|The RSK address that will receive the RBTC|
|`_value`|`uint64`|The amount in satoshis to peg in (must match stream denomination)|
|`_btcReimbursementPubKey`|`bytes32`|The user's Bitcoin public key (x-coordinate only, 32 bytes)|
|`_committeePubKey`|`bytes32`|The committee's public key (x-coordinate only, 32 bytes)|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`temporaryPeginAddress`|`string`|The generated temporary Bitcoin address for deposit|


### getPeginOpReturnData

Extracts data from a request peg-in Bitcoin transaction's OP_RETURN output

*Expected OP_RETURN format: [OP_RETURN][RSK_PEGIN][packet number][rsk address][btc address]*

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


```solidity
function validateRequestPeginP2TROutput(
    address _rskDestinationAddress,
    uint64 _streamDenomination,
    bytes32 _btcReimbursementPubKey,
    bytes32 _committeePubKey,
    BtcTxOut calldata _p2trOut
) external pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_rskDestinationAddress`|`address`|The RSK address that should receive the RBTC|
|`_streamDenomination`|`uint64`|The expected amount in satoshis|
|`_btcReimbursementPubKey`|`bytes32`|The user's Bitcoin public key (x-coordinate only)|
|`_committeePubKey`|`bytes32`|The committee's public key (x-coordinate only)|
|`_p2trOut`|`BtcTxOut`|The Bitcoin transaction output to validate|


### getBtcTxHash

Calculates the Bitcoin transaction hash (txid) for a given transaction

*Encodes the transaction into Bitcoin's raw format and performs double SHA256 hash*

*This is the standard Bitcoin transaction ID used for referencing transactions*


```solidity
function getBtcTxHash(BtcTransaction calldata _btcTx) external pure returns (bytes32);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_btcTx`|`BtcTransaction`|The Bitcoin transaction to hash|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|txHash The transaction hash in big-endian format (standard hex representation)|


### getPeginRequestP2TRScriptPub

Generates a Taproot script pub key for peg-in request transactions

*Creates a P2TR script with both key spend and script spend paths for committee and user keys*


```solidity
function getPeginRequestP2TRScriptPub(
    address _rskDestinationAddress,
    uint64 _value,
    bytes32 _btcReimbursementPubKey,
    bytes32 _committeePubKey
) external pure returns (bytes memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_rskDestinationAddress`|`address`|The RSK address that will receive the RBTC|
|`_value`|`uint64`|The amount in satoshis (must match stream denomination)|
|`_btcReimbursementPubKey`|`bytes32`|The user's public key (x-coordinate only, 32 bytes)|
|`_committeePubKey`|`bytes32`|The committee's public key (x-coordinate only, 32 bytes)|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes`|The generated Taproot script pub key|


### getAcceptPeginSignatureHash

Calculates the signature hash for Bitcoin accept peg-in transactions

*Generates the hash that committee members must sign to accept a peg-in*


```solidity
function getAcceptPeginSignatureHash(
    bytes32 _committeePubKey,
    bytes32 _userXOnlyPubKey,
    bytes32 _registerPeginTx,
    PrevoutData memory _prevoutData
) external pure returns (bytes32, bytes32, bytes memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_committeePubKey`|`bytes32`|The committee's public key (x-coordinate only)|
|`_userXOnlyPubKey`|`bytes32`|The user's public key (x-coordinate only, 32 bytes)|
|`_registerPeginTx`|`bytes32`|The transaction hash of the peg-in request being spent|
|`_prevoutData`|`PrevoutData`|Data about the previous output being spent (amount and scriptPubKey)|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|acceptPeginTxHash The hash of the accept peg-in transaction|
|`<none>`|`bytes32`|acceptPeginSignatureHash The hash that needs to be signed by committee members|
|`<none>`|`bytes`|acceptPeginSignatureMessage The encoded data before hashing|


### getAcceptPeginP2TRScriptPub

Generates a Taproot script pub key for accept peg-in transactions

*Creates a P2TR script with committee key path for accepting peg-ins*


```solidity
function getAcceptPeginP2TRScriptPub(bytes32 _committeePubKey) external pure returns (bytes memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_committeePubKey`|`bytes32`|The committee's public key (x-coordinate only, 32 bytes)|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes`|The Taproot script pub key for the accept peg-in output|


### validateAcceptPeginP2TROutput

Validates a P2TR output for accept peg-in transactions

*Ensures the Taproot output has the correct committee key structure*


```solidity
function validateAcceptPeginP2TROutput(bytes32 _committeePubKey, uint64 _inputAmount, BtcTxOut calldata _p2trOut)
    external
    pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_committeePubKey`|`bytes32`|The committee's public key (x-coordinate only, 32 bytes)|
|`_inputAmount`|`uint64`|The amount of the input being spent|
|`_p2trOut`|`BtcTxOut`|The Bitcoin transaction output containing the P2TR output|


### getSpeedUpScriptPub

Generates a P2WPKH script pub key for speed-up outputs

*Creates a P2WPKH script for Child Pays for Parent (CPFP) transactions to speed up the original transaction*


```solidity
function getSpeedUpScriptPub(bytes32 _pubKey) external pure returns (bytes memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_pubKey`|`bytes32`|The user's public key (x-coordinate only, 32 bytes)|

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


### getPegoutSignatureHash

Calculates the signature hash for Bitcoin peg-out transactions

*Generates the hash that committee members must sign to authorize a peg-out*


```solidity
function getPegoutSignatureHash(bytes memory _userPubKey, bytes32 _acceptPeginTx, PrevoutData memory _prevoutData)
    external
    pure
    returns (bytes32, bytes memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_userPubKey`|`bytes`|The user's public key in compressed format that will receive the funds|
|`_acceptPeginTx`|`bytes32`|The transaction hash of the accept peg-in tx being spent|
|`_prevoutData`|`PrevoutData`|Data about the previous output being spent (amount and scriptPubKey)|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|pegoutSignatureHash The hash that needs to be signed by committee members|
|`<none>`|`bytes`|pegoutSignatureMessage The encoded data before hashing|


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
function validatePegoutMemberOutput(BtcTxOut calldata _pegoutOutput, bytes32 _memberPubKey) external pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_pegoutOutput`|`BtcTxOut`|The Bitcoin transaction output to validate|
|`_memberPubKey`|`bytes32`|The committee member's public key that should receive the funds|


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

