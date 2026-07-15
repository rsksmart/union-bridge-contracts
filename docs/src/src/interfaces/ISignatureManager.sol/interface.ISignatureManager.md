# ISignatureManager
[Git Source](https://github.com/rsksmart/union-bridge-contracts/blob/cf5421e1f47ca597147a56a1404f8189f6c70b20/src/interfaces/ISignatureManager.sol)

Interface for managing multi-signature operations in the union bridge

*This interface provides functions for collecting and validating committee signatures*

*Handles member signatures for both pegin and pegout transactions*


## Functions
### initSignatures

Initializes signature collection for a specific txid

*Sets up the signature tracking structure for committee members*


```solidity
function initSignatures(bytes32 _txid, uint128 _committeeId) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_txid`|`bytes32`|The txid that committee members need to sign|
|`_committeeId`|`uint128`|The ID of the committee responsible for signing|


### addMemberNonce

Adds a nonce for a committee member to the signature collection

*Nonces are required for Musig2 signature aggregation*


```solidity
function addMemberNonce(bytes32 _txid, bytes memory _nonce) external returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_txid`|`bytes32`|The txid that needs to be signed by the committee|
|`_nonce`|`bytes`|The 66-byte nonce for the Musig2 protocol|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|true if all nonces are now present, false otherwise|


### addMemberSignature

Adds a signature for a committee member to the signature collection

*Signatures can only be added after all nonces are present*


```solidity
function addMemberSignature(bytes32 _txid, bytes32 _signature) external returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_txid`|`bytes32`|The hash that needs to be signed by the committee|
|`_signature`|`bytes32`|The signature for the hash|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|true if all signatures are now present, false otherwise|


### checkAllSignaturesReady

Checks if all signatures are ready for a given hash


```solidity
function checkAllSignaturesReady(bytes32 _txid) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_txid`|`bytes32`|The hash to check signatures for|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|true if all signatures are present, false otherwise|


### getPartialSignatures

Gets all partial signatures for a given hash

*Returns signatures in the same order as committee members for Musig2 compatibility*


```solidity
function getPartialSignatures(bytes32 _txid)
    external
    view
    returns (SignatureData[] memory partialSignaturesData, uint8 missingNonces, uint128 committeeId);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_txid`|`bytes32`|The hash to get signatures for|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`partialSignaturesData`|`SignatureData[]`|Array of signature data for all committee members|
|`missingNonces`|`uint8`|Number of missing nonces|
|`committeeId`|`uint128`|The committee ID for this signature collection|


### initOperatorTakeTxids

Initializes OperatorTake transaction id collection for a given accept peg-in transaction

*Sets up the OperatorTake txid tracking structure for committee members*

*Can only be called by the PegManager*


```solidity
function initOperatorTakeTxids(bytes32 _acceptPeginTxid, uint128 _committeeId) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_acceptPeginTxid`|`bytes32`|The accept peg-in transaction id|
|`_committeeId`|`uint128`|The ID of the committee responsible for OperatorTake operations|


### addOperatorTakeTxids

Adds a OperatorTake and OperatorWon transaction id for an operator

*Only operators can add OperatorTake transaction id's*


```solidity
function addOperatorTakeTxids(bytes32 _acceptPeginTxid, bytes32 _takeTxid, bytes32 _wonTxid) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_acceptPeginTxid`|`bytes32`|The accept peg-in transaction id|
|`_takeTxid`|`bytes32`|The OperatorTake transaction id to add|
|`_wonTxid`|`bytes32`|The OperatorWon transaction id to add|


### checkAllOperatorTakesHashesReady

Checks if all OperatorTake transaction id's are ready for a given accept peg-in transaction


```solidity
function checkAllOperatorTakesHashesReady(bytes32 _acceptPeginTxid) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_acceptPeginTxid`|`bytes32`|The accept peg-in transaction id to check|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|true if all OperatorTake transaction id's are present, false otherwise|


### getMissingOperatorTakeHashes

Gets the number of missing OperatorTake transaction id's for a given accept peg-in transaction


```solidity
function getMissingOperatorTakeHashes(bytes32 _acceptPeginTxid) external view returns (uint8);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_acceptPeginTxid`|`bytes32`|The accept peg-in transaction id|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint8`|The number of missing OperatorTake transaction id's|


### getOperatorTakeData

Gets all OperatorTake transaction data for a given accept peg-in transaction


```solidity
function getOperatorTakeData(bytes32 _acceptPeginTxid) external view returns (OperatorTakeData[] memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_acceptPeginTxid`|`bytes32`|The accept peg-in transaction id|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`OperatorTakeData[]`|Array of OperatorTake transaction data for all operators|


### getCommitteeIdByAcceptPeginTxid

Gets the committee ID for a specific accept peg-in transaction id


```solidity
function getCommitteeIdByAcceptPeginTxid(bytes32 _acceptPeginTxid) external view returns (uint128);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_acceptPeginTxid`|`bytes32`|The accept peg-in transaction id|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint128`|The committee ID responsible for this accept peg-in|


## Events
### NonceAdded
Event emitted when a nonce is added by a committee member


```solidity
event NonceAdded(bytes32 indexed txid, address indexed memberAddress, bytes nonce);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`txid`|`bytes32`|The txid being signed|
|`memberAddress`|`address`|The member's RSK address|
|`nonce`|`bytes`|The nonce provided by the member|

### AllNoncesReady
Event emitted when all nonces are ready for a hash


```solidity
event AllNoncesReady(bytes32 indexed txid);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`txid`|`bytes32`|The txid for which all nonces are ready|

### SignatureAdded
Event emitted when a signature is added by a committee member


```solidity
event SignatureAdded(bytes32 indexed txid, address indexed memberAddress, bytes32 signature);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`txid`|`bytes32`|The txid being signed|
|`memberAddress`|`address`|The member's RSK address|
|`signature`|`bytes32`|The signature provided by the member|

### AllSignaturesReady
Event emitted when all signatures are ready for a hash


```solidity
event AllSignaturesReady(bytes32 indexed txid);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`txid`|`bytes32`|The txid for which all signatures are ready|

### OperatorTakeTxidsAdded
Event emitted when OperatorTake and OperatorWon transaction id are added for a member


```solidity
event OperatorTakeTxidsAdded(
    bytes32 indexed acceptPeginTxid, address indexed memberAddress, bytes32 takeTxid, bytes32 wonTxid
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`acceptPeginTxid`|`bytes32`|The accept peg-in transaction id|
|`memberAddress`|`address`|The member's address|
|`takeTxid`|`bytes32`|The OperatorTake transaction id provided by the member|
|`wonTxid`|`bytes32`|The OperatorWon transaction id provided by the member|

### AllOperatorTakeTxidsAdded
Event emitted when all OperatorTake and OperatorWon transaction id's are added


```solidity
event AllOperatorTakeTxidsAdded(bytes32 acceptPeginTxid);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`acceptPeginTxid`|`bytes32`|The accept peg-in transaction id|

## Errors
### InvalidZeroAddress
Thrown when the committee registry address is set to zero


```solidity
error InvalidZeroAddress();
```

### TxidToSignNotFound
Thrown when a txid to sign is not found


```solidity
error TxidToSignNotFound(bytes32 txid);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`txid`|`bytes32`|The txid that was not found|

### InvalidNonceLength
Thrown when the nonce length is invalid


```solidity
error InvalidNonceLength(uint256 actual, uint8 expected);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`actual`|`uint256`|The actual nonce length|
|`expected`|`uint8`|The expected nonce length (66 bytes)|

### MemberAlreadyAddedNonce
Thrown when a member has already added a nonce


```solidity
error MemberAlreadyAddedNonce(address memberAddress, bytes nonce);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`memberAddress`|`address`|The member's address|
|`nonce`|`bytes`|The nonce that was already added|

### AllNoncesAreNotPresent
Thrown when all nonces are not present


```solidity
error AllNoncesAreNotPresent(bytes32 txid);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`txid`|`bytes32`|The txid for which nonces are missing|

### InvalidSignature
Thrown when a signature is invalid


```solidity
error InvalidSignature();
```

### MemberHasAlreadySigned
Thrown when a member has already signed


```solidity
error MemberHasAlreadySigned(address memberAddress, bytes32 pegoutTxid);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`memberAddress`|`address`|The member's address|
|`pegoutTxid`|`bytes32`|The peg-out transaction id|

### MemberNotFound
Thrown when a member is not found


```solidity
error MemberNotFound(address memberAddress);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`memberAddress`|`address`|The member's address|

### MemberNotFoundInCommittee
Thrown when a member is not found in a committee


```solidity
error MemberNotFoundInCommittee(uint128 committeeId, address memberAddress);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`committeeId`|`uint128`|The committee ID|
|`memberAddress`|`address`|The member's address|

### InvalidTxidToSign
Thrown when the hash to sign is invalid


```solidity
error InvalidTxidToSign(bytes32 txid);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`txid`|`bytes32`|The invalid txid|

### SignaturesAlreadyInitialized
Thrown when signatures are already initialized


```solidity
error SignaturesAlreadyInitialized(bytes32 txid);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`txid`|`bytes32`|The txid for which signatures are already initialized|

### InvalidAcceptPeginTxid
Thrown when the accept peg-in transaction id is invalid


```solidity
error InvalidAcceptPeginTxid(bytes32 acceptPeginTxid);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`acceptPeginTxid`|`bytes32`|The invalid accept peg-in transaction id|

### OperatorTakeTxidsAlreadyInitialized
Thrown when OperatorTake transaction id's are already initialized


```solidity
error OperatorTakeTxidsAlreadyInitialized(bytes32 acceptPeginTxid);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`acceptPeginTxid`|`bytes32`|The accept peg-in transaction id|

### AcceptPeginTxidNotFound
Thrown when an accept peg-in transaction id is not found


```solidity
error AcceptPeginTxidNotFound(bytes32 acceptPeginTxid);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`acceptPeginTxid`|`bytes32`|The accept peg-in transaction id that was not found|

### AllOperatorTakeTxidsAlreadyPresent
Thrown when all OperatorTake transaction id's are already present


```solidity
error AllOperatorTakeTxidsAlreadyPresent(bytes32 acceptPeginTxid);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`acceptPeginTxid`|`bytes32`|The accept peg-in transaction id|

### InvalidHash
Thrown when a hash is invalid


```solidity
error InvalidHash(bytes32 hash);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`hash`|`bytes32`|The invalid hash|

### MemberIsNotOperator
Thrown when a member is not an operator


```solidity
error MemberIsNotOperator(uint128 committeeId, address memberAddress);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`committeeId`|`uint128`|The committee ID|
|`memberAddress`|`address`|The member's address|

### MemberAlreadyAddedOperatorTakeTxids
Thrown when a member has already added OperatorTake and OperatorWon transaction ids


```solidity
error MemberAlreadyAddedOperatorTakeTxids(
    bytes32 acceptPeginTxid, address memberAddress, bytes32 takeTxid, bytes32 wonTxid
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`acceptPeginTxid`|`bytes32`|The accept peg-in transaction id|
|`memberAddress`|`address`|The member's address|
|`takeTxid`|`bytes32`|The OperatorTake transaction id that was already added|
|`wonTxid`|`bytes32`|The OperatorWon transaction id that was already added|

