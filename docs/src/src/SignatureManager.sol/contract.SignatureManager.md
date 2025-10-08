# SignatureManager
[Git Source](https://github.com/FairgateLabs/bitvmx-union-bridge-contracts/blob/5935b1ba9b5693ff58c693caac2763a4b158c822/src/SignatureManager.sol)

**Inherits:**
[ISignatureManager](/src/interfaces/ISignatureManager.sol/interface.ISignatureManager.md), [AccessControl](/src/AccessControl.sol/contract.AccessControl.md)

Manages signatures for peg-in and peg-out operations

*Handles multi-signature operations for committee members using Musig2 protocol*

*Manages both signature collection and OperatorTake transaction id collection*


## State Variables
### committeeRegistry
The committee registry contract that manages committee membership

*Used to verify committee membership and get member information*


```solidity
ICommitteeRegistry public committeeRegistry;
```


### committeeSignatures

```solidity
mapping(bytes32 hashToSign => Signatures signatures) internal committeeSignatures;
```


### operatorTakeTxidsMap

```solidity
mapping(bytes32 acceptPeginTxid => OperatorTakeTxids operatorTakeTxids) internal operatorTakeTxidsMap;
```


## Functions
### initialize

Initializes the SignatureManager contract

*Sets up the committee registry and access control*

*Can only be called once during contract deployment*


```solidity
function initialize(address _initialOwner, address _pegManager, ICommitteeRegistry _committeeRegistry)
    public
    initializer;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_initialOwner`|`address`|The address that will be set as the initial owner|
|`_pegManager`|`address`|The address of the PegManager contract|
|`_committeeRegistry`|`ICommitteeRegistry`|The address of the CommitteeRegistry contract|


### _isMemberInCommittee


```solidity
function _isMemberInCommittee(uint128 _committeeId, address _memberAddress) internal view returns (bool);
```

### _getMemberRole


```solidity
function _getMemberRole(uint128 _committeeId, address _memberAddress) internal view returns (Role);
```

### addMemberNonce

Adds a nonce for a committee member to the signature collection

*Nonces are required for Musig2 signature aggregation*


```solidity
function addMemberNonce(bytes32 _hashToSign, bytes memory _nonce) external returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_hashToSign`|`bytes32`|The hash that needs to be signed by the committee|
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
function getPartialSignatures(bytes32 _txid) external view returns (SignatureData[] memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_txid`|`bytes32`|The hash to get signatures for|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`SignatureData[]`|Array of signature data for all committee members|


### getSignaturesStatus

Gets the status of the signatures for a given hash


```solidity
function getSignaturesStatus(bytes32 _txid) external view returns (uint8, uint8, uint128);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_txid`|`bytes32`|The hash to get status for|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint8`|missingSignatures Number of missing signatures|
|`<none>`|`uint8`|missingNonces Number of missing nonces|
|`<none>`|`uint128`|committeeId The committee ID for this signature collection|


### _getSignatures


```solidity
function _getSignatures(bytes32 _txid) internal view returns (Signatures storage);
```

### initSignatures

Initializes signature collection for a given hash

*Can only be called by the PegManager*


```solidity
function initSignatures(bytes32 _txid, uint128 _committeeId) external onlyPegManager;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_txid`|`bytes32`|The hash that needs to be signed|
|`_committeeId`|`uint128`|The committee ID that will sign the hash|


### initOperatorTakeTxids

Initializes OperatorTake transaction id collection for a given accept peg-in transaction

*Can only be called by the PegManager*


```solidity
function initOperatorTakeTxids(bytes32 _acceptPeginTxid, uint128 _committeeId) external onlyPegManager;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_acceptPeginTxid`|`bytes32`|The accept peg-in transaction id|
|`_committeeId`|`uint128`|The committee ID that will provide OperatorTake transaction id's|


### _getOperatorTakeTxids


```solidity
function _getOperatorTakeTxids(bytes32 _acceptPeginTxid) internal view returns (OperatorTakeTxids storage);
```

### addOperatorTakeTxid

Adds a OperatorTake transaction id for an operator

*Only operators can add OperatorTake transaction id's*


```solidity
function addOperatorTakeTxid(bytes32 _acceptPeginTxid, bytes32 _takeTxid) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_acceptPeginTxid`|`bytes32`|The accept peg-in transaction id|
|`_takeTxid`|`bytes32`|The OperatorTake transaction id to add|


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

Gets the committee ID for a given accept peg-in transaction id


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
|`<none>`|`uint128`|The committee ID associated with this transaction id|


