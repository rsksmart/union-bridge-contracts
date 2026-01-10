# ISignatureManager
[Git Source](https://github.com/temp-rsk/bitvmx-union-bridge-contracts/blob/71daf3bfeba3a077e1d33188a46c6e2cfea30519/src/interfaces/ISignatureManager.sol)

**Inherits:**
[IAccessControl](/src/interfaces/IAccessControl.sol/interface.IAccessControl.md)

Interface for managing multi-signature operations in the union bridge

*This interface provides functions for collecting and validating committee signatures*

*Handles member signatures for both pegin and pegout transactions*


## Functions
### initSignatures

Initializes signature collection for a specific hash

*Sets up the signature tracking structure for committee members*


```solidity
function initSignatures(bytes32 _hashToSign, uint128 _committeeId) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_hashToSign`|`bytes32`|The hash that committee members need to sign|
|`_committeeId`|`uint128`|The ID of the committee responsible for signing|


### addMemberNonce

Adds a nonce for a committee member

*Called by committee members to provide their nonce for signature generation*


```solidity
function addMemberNonce(bytes32 _hashToSign, bytes memory _nonce) external returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_hashToSign`|`bytes32`|The hash being signed|
|`_nonce`|`bytes`|The nonce provided by the member (should be 66 bytes)|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if the nonce was successfully added|


### addMemberSignature

Adds a signature for a committee member

*Called by committee members to provide their signature*


```solidity
function addMemberSignature(bytes32 _hashToSign, bytes32 _signature) external returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_hashToSign`|`bytes32`|The hash being signed|
|`_signature`|`bytes32`|The signature provided by the member|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if the signature was successfully added|


### checkAllSignaturesReady

Checks if all signatures are ready for a specific hash


```solidity
function checkAllSignaturesReady(bytes32 _hashToSign) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_hashToSign`|`bytes32`|The hash to check signatures for|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if all required signatures have been collected|


### getPartialSignatures

Retrieves all partial signatures for a specific hash


```solidity
function getPartialSignatures(bytes32 _hashToSign) external view returns (SignatureData[] memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_hashToSign`|`bytes32`|The hash to get signatures for|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`SignatureData[]`|Array of signature data from all committee members|


### getSignaturesStatus

Gets the status of signatures for a specific hash


```solidity
function getSignaturesStatus(bytes32 _hashToSign)
    external
    view
    returns (uint8 missingSignatures, uint8 missingNonces, uint128 committeeId);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_hashToSign`|`bytes32`|The hash to check status for|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`missingSignatures`|`uint8`|Number of missing signatures|
|`missingNonces`|`uint8`|Number of missing nonces|
|`committeeId`|`uint128`|The committee ID responsible for these signatures|


### initOperatorTakeTxids

Initializes OperatorTake transaction id collection for a specific accept peg-in

*Sets up the OperatorTake hash tracking structure for committee members*


```solidity
function initOperatorTakeTxids(bytes32 _acceptPeginTxid, uint128 _committeeId) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_acceptPeginTxid`|`bytes32`|The accept peg-in transaction id|
|`_committeeId`|`uint128`|The ID of the committee responsible for OperatorTake operations|


### addOperatorTakeTxid

Adds a OperatorTake transaction id for a committee member

*Called by committee operators to provide their OperatorTake transaction id*


```solidity
function addOperatorTakeTxid(bytes32 _acceptPeginTxid, bytes32 _takeTxid) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_acceptPeginTxid`|`bytes32`|The accept peg-in transaction id|
|`_takeTxid`|`bytes32`|The OperatorTake transaction id provided by the member|


### checkAllOperatorTakesHashesReady

Checks if all OperatorTake transaction id's are ready


```solidity
function checkAllOperatorTakesHashesReady(bytes32 _acceptPeginTxid) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_acceptPeginTxid`|`bytes32`|The accept peg-in transaction id|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if all required OperatorTake hashes have been collected|


### getOperatorTakeData

Retrieves all OperatorTake data for a specific accept peg-in


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
|`<none>`|`OperatorTakeData[]`|Array of OperatorTake data from all committee members|


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
event NonceAdded(bytes32 indexed hashToSign, address indexed memberAddress, bytes nonce);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`hashToSign`|`bytes32`|The hash being signed|
|`memberAddress`|`address`|The member's RSK address|
|`nonce`|`bytes`|The nonce provided by the member|

### AllNoncesReady
Event emitted when all nonces are ready for a hash


```solidity
event AllNoncesReady(bytes32 indexed hashToSign);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`hashToSign`|`bytes32`|The hash for which all nonces are ready|

### SignatureAdded
Event emitted when a signature is added by a committee member


```solidity
event SignatureAdded(bytes32 indexed hashToSign, address indexed memberAddress, bytes32 signature);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`hashToSign`|`bytes32`|The hash being signed|
|`memberAddress`|`address`|The member's RSK address|
|`signature`|`bytes32`|The signature provided by the member|

### AllSignaturesReady
Event emitted when all signatures are ready for a hash


```solidity
event AllSignaturesReady(bytes32 indexed hashToSign);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`hashToSign`|`bytes32`|The hash for which all signatures are ready|

### OperatorTakeTxidAdded
Event emitted when a OperatorTake transaction id is added


```solidity
event OperatorTakeTxidAdded(bytes32 acceptPeginTxid, address memberAddress, bytes32 hash);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`acceptPeginTxid`|`bytes32`|The accept peg-in transaction id|
|`memberAddress`|`address`|The member's address|
|`hash`|`bytes32`|The OperatorTake transaction id provided by the member|

### AllOperatorTakeTxidsAdded
Event emitted when all OperatorTake transaction id's are added


```solidity
event AllOperatorTakeTxidsAdded(bytes32 acceptPeginTxid);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`acceptPeginTxid`|`bytes32`|The accept peg-in transaction id|

## Errors
### CommitteeRegistryAddressZero
Thrown when the committee registry address is set to zero


```solidity
error CommitteeRegistryAddressZero();
```

### HashToSignNotFound
Thrown when a hash to sign is not found


```solidity
error HashToSignNotFound(bytes32 hashToSign);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`hashToSign`|`bytes32`|The hash that was not found|

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
error AllNoncesAreNotPresent(bytes32 hashToSign);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`hashToSign`|`bytes32`|The hash for which nonces are missing|

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

### InvalidHashToSign
Thrown when the hash to sign is invalid


```solidity
error InvalidHashToSign(bytes32 hashToSign);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`hashToSign`|`bytes32`|The invalid hash|

### SignaturesAlreadyInitialized
Thrown when signatures are already initialized


```solidity
error SignaturesAlreadyInitialized(bytes32 hashToSign);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`hashToSign`|`bytes32`|The hash for which signatures are already initialized|

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

### MemberAlreadyAddedOperatorTakeTxid
Thrown when a member has already added a OperatorTake transaction id


```solidity
error MemberAlreadyAddedOperatorTakeTxid(bytes32 acceptPeginTxid, address memberAddress, bytes32 hash);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`acceptPeginTxid`|`bytes32`|The accept peg-in transaction id|
|`memberAddress`|`address`|The member's address|
|`hash`|`bytes32`|The OperatorTake transaction id that was already added|

