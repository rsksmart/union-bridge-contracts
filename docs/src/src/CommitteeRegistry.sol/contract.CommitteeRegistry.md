# CommitteeRegistry
[Git Source](https://github.com/FairgateLabs/bitvmx-union-bridge-contracts/blob/d1d7e57632b0c5f559c5c50994a17b0f4b09c742/src/CommitteeRegistry.sol)

**Inherits:**
[ICommitteeRegistry](/src/interfaces/ICommitteeRegistry.sol/interface.ICommitteeRegistry.md), [BaseProxy](/src/BaseProxy.sol/abstract.BaseProxy.md)

Manages committee formation, selection, and lifecycle for the union bridge system

*Handles committee creation, pending committee management, and coordination with MemberRegistry*


## State Variables
### minCommitteeWatchtowers
Minimum number of watchtowers required for a committee


```solidity
uint256 public minCommitteeWatchtowers;
```


### minCommitteeOperators
Minimum number of operators required for a committee


```solidity
uint256 public minCommitteeOperators;
```


### committeeMemberCount
Minimum number of members required for a committee


```solidity
uint256 public committeeMemberCount;
```


### pendingCommittees
Mapping of streamId to the committee id


```solidity
mapping(uint64 streamId => uint128) internal pendingCommittees;
```


### committeesById
Mapping of committeeId to committee data


```solidity
mapping(uint128 committeeId => Committee) internal committeesById;
```


### committeesData
Mapping of member addresses to their pending data


```solidity
mapping(uint128 committeeId => mapping(address memberAddress => PendingCommitteeData)) committeesData;
```


### shouldCreateCommittee
Mapping of streamId to flag indicating if a committee should be created


```solidity
mapping(uint64 streamId => bool createCommittee) public shouldCreateCommittee;
```


### streamManager
Stream manager contract for managing streams and packets


```solidity
IStreamManager streamManager;
```


### pegManager
Peg manager contract for peg-in/peg-out coordination


```solidity
IPegManager pegManager;
```


### memberRegistry
Member registry contract for member management


```solidity
IMemberRegistry public memberRegistry;
```


### pendingCommitteeTimeout
Timeout in seconds for pending committee formation


```solidity
uint256 public pendingCommitteeTimeout;
```


## Functions
### initialize

Initializes the CommitteeRegistry contract


```solidity
function initialize(address _initialOwner) public virtual initializer;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_initialOwner`|`address`|The initial owner of the contract|


### _revertIfZero


```solidity
function _revertIfZero(uint256 _value) internal pure;
```

### applyToStream

Applies to participate in a stream with a specific role

*Registers public keys, deposits required bond, and provides funding UTXO for the requested role*


```solidity
function applyToStream(
    StreamDenomination _stream,
    Role _role,
    MemberRegistrationKeys calldata _publicKeys,
    UTXO calldata _fundingUTXO
) external payable;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_stream`|`StreamDenomination`|The stream denomination to apply for|
|`_role`|`Role`|The role requested in the committee|
|`_publicKeys`|`MemberRegistrationKeys`|Member registration public keys|
|`_fundingUTXO`|`UTXO`|The Bitcoin UTXO that will be used for the member funding|


### unsubscribeFromStream

Unsubscribes from a stream and sets the pre-staked balance as available


```solidity
function unsubscribeFromStream(StreamDenomination _denomination) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_denomination`|`StreamDenomination`|The stream denomination to unsubscribe from|


### _isInPendingCommittee


```solidity
function _isInPendingCommittee(address _memberAddress, uint64 _streamId) internal view returns (bool);
```

### getCommittee

Gets a committee by its ID


```solidity
function getCommittee(uint128 _committeeId) external view returns (Committee memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_committeeId`|`uint128`|The committee ID|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`Committee`|Committee The complete committee information|


### _getCommittee


```solidity
function _getCommittee(uint128 _committeeId) internal view returns (Committee storage);
```

### getCommitteeMembers

Gets all members of a specific committee


```solidity
function getCommitteeMembers(uint128 _committeeId) external view returns (CommitteeMember[] memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_committeeId`|`uint128`|The committee ID|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`CommitteeMember[]`|Array of committee members with their roles|


### _getCommitteeMembers


```solidity
function _getCommitteeMembers(uint128 _committeeId) internal view returns (CommitteeMember[] memory);
```

### restartPendingCommittee


```solidity
function restartPendingCommittee(uint64 _streamId) external;
```

### createCommittee

Triggers the creation of a new committee for a stream if the timeout has expired

*This function is called when the slot usage threshold is reached*


```solidity
function createCommittee(uint64 _streamId) external onlyPegManager;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_streamId`|`uint64`|The stream ID to create a new committee for|


### _createCommitteeAfterApplyToStream


```solidity
function _createCommitteeAfterApplyToStream(StreamDenomination _denomination) internal;
```

### _createCommitteeIfPending


```solidity
function _createCommitteeIfPending(uint64 _streamId) internal returns (bool);
```

### _createCommittee


```solidity
function _createCommittee(uint64 _streamId) internal returns (PendingCommitteeStatus);
```

### _isInCommitteeOrRevert


```solidity
function _isInCommitteeOrRevert(uint128 _committeeId, address _memberAddress) internal view;
```

### depositAggregatedKey

Allows a member to deposit information for committee formation

*Called by members to provide their aggregated key for a pending committee*


```solidity
function depositAggregatedKey(uint128 _committeeId, bytes memory _aggregatedKey) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_committeeId`|`uint128`|The ID of the pending committee|
|`_aggregatedKey`|`bytes`|The aggregated public key provided by the member|


### depositCommunicationData


```solidity
function depositCommunicationData(uint128 _committeeId, CommunicationData[] memory _communicationData) external;
```

### getMemberCommunicationData

Gets the encrypted communication data for one member in a committee

*This function returns the encrypted communication data (IP and Port) deposited for a particular member*

*The order of the data corresponds to the order of members in the committee*


```solidity
function getMemberCommunicationData(uint128 _committeeId, address _memberAddress)
    external
    view
    returns (CommunicationData[] memory communicationData);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_committeeId`|`uint128`|The committee ID for the committee|
|`_memberAddress`|`address`|The address of the member we are requesting data for|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`communicationData`|`CommunicationData[]`|encrypted communication data (IP and Port) from the committee members|


### getPendingCommittee

Returns the pending committee for the stream

*This function will revert if  there is no pending committee or if it's expired*


```solidity
function getPendingCommittee(uint64 _streamId) external view returns (Committee memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_streamId`|`uint64`|The stream ID to get the pending committee for|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`Committee`|committee The pending committee (contains createdAt and missingData fields)|


### getPendingCommitteeId

Returns the committee ID for a pending committee in the given stream


```solidity
function getPendingCommitteeId(uint64 _streamId) external view returns (uint128 committeeId);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_streamId`|`uint64`|The stream ID to get the pending committee ID for|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`committeeId`|`uint128`|The committee ID of the pending committee|


### _getPendingCommitteeId


```solidity
function _getPendingCommitteeId(uint64 _streamId) internal view returns (uint128 committeeId);
```

### getMissingCommunicationDataCount

Returns the number of members that have not deposited their communication data yet


```solidity
function getMissingCommunicationDataCount(uint128 _committeeId)
    external
    view
    returns (uint16 missingCommunicationData);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_committeeId`|`uint128`|The committee ID to check for missing communication data|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`missingCommunicationData`|`uint16`|The number of members that have not deposited their communication data yet|


### _getPendingCommittee


```solidity
function _getPendingCommittee(uint64 _streamId) internal view returns (Committee storage);
```

### _getPendingCommitteeById


```solidity
function _getPendingCommitteeById(uint128 _committeeId) internal view returns (Committee storage);
```

### isPendingCommitteeExpired

Checks if there is a pending committee for the stream and if it's expired


```solidity
function isPendingCommitteeExpired(uint64 _streamId) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_streamId`|`uint64`|The stream ID to check for a pending committee|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if the pending committee exists and is expired|


### _deletePendingCommittee


```solidity
function _deletePendingCommittee(uint64 _streamId) internal;
```

### getOperatorTakeAddress

Gets the next available operator address for take operations

*Rotates through committee operators to distribute take responsibilities*

*Only operators who have deposited their signatures nonces are eligible for take operations*

*Reverts with TakeOperatorNotFound if no eligible operator is found*


```solidity
function getOperatorTakeAddress(uint128 _committeeId, SignatureData[] calldata _signatureData)
    external
    onlyPegManager
    returns (address);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_committeeId`|`uint128`|The committee ID to get the operator from|
|`_signatureData`|`SignatureData[]`|Array of signature data for committee members|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The address of the next available operator for take operations|


### setStreamManager

Sets the Stream Manager contract address

*Only callable by the contract owner*


```solidity
function setStreamManager(IStreamManager _streamManager) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_streamManager`|`IStreamManager`|The address of the Stream Manager contract|


### setPegManager

Sets the Peg Manager contract address

*Only callable by the contract owner*


```solidity
function setPegManager(IPegManager _pegManager) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_pegManager`|`IPegManager`|The address of the Peg Manager contract|


### setMemberRegistry

Sets the Member Registry contract address


```solidity
function setMemberRegistry(IMemberRegistry _memberRegistry) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_memberRegistry`|`IMemberRegistry`|The address of the Member Registry contract|


### setPendingCommitteeTimeout

Sets the pending committee timeout

*Only callable by the contract owner*


```solidity
function setPendingCommitteeTimeout(uint256 _timeout) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_timeout`|`uint256`|The timeout in seconds for the pending committee|


### setCommitteeMinWatchtowers

Sets the minimum watchtowers required for a committee

*Only callable by the contract owner*


```solidity
function setCommitteeMinWatchtowers(uint256 _minWatchtowers) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_minWatchtowers`|`uint256`|The minimum watchtowers required for a committee|


### setCommitteeMinOperators

Sets the minimum operators required for a committee

*Only callable by the contract owner*


```solidity
function setCommitteeMinOperators(uint256 _minOperators) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_minOperators`|`uint256`|The minimum operators required for a committee|


### setCommitteeMemberCount

Sets the exact number of members required for a committee

*Only callable by the contract owner*


```solidity
function setCommitteeMemberCount(uint256 _committeeMemberCount) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_committeeMemberCount`|`uint256`|The exact number of members required for a committee|


### releaseCommittee

Releases committee members from a packet and handles their staked balance

*Called by PegManager to release committee members after packet completion*

*Members with reApply=true will be re-added as candidates, others get their balance as available*


```solidity
function releaseCommittee(uint64 _streamId, uint64 _packetNumber) external onlyPegManager;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_streamId`|`uint64`|The stream ID for the committee|
|`_packetNumber`|`uint64`|The packet number where the committee was active|


### onlyPegManager

Modifier to restrict access to the PegManager contract


```solidity
modifier onlyPegManager();
```

### _onlyPegManager


```solidity
function _onlyPegManager(address _account) internal view;
```

