# ICommitteeRegistry
[Git Source](https://github.com/FairgateLabs/bitvmx-union-bridge-contracts/blob/0b531d846dee21847f46b6304e71a6006a2ef7c3/src/interfaces/ICommitteeRegistry.sol)

Interface for managing committee registration and formation in the union bridge

*This interface provides functions for member registration, committee formation,*

*and balance management for the committee system*


## Functions
### applyToStream

Applies to participate in a stream with a specific role

*Registers public keys, deposits required bond, and provides funding UTXO for the requested role*


```solidity
function applyToStream(
    StreamDenomination _requestedStream,
    Role _requestedRole,
    MemberRegistrationKeys calldata _publicKeys,
    UTXO calldata _fundingUTXO
) external payable;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_requestedStream`|`StreamDenomination`|The stream denomination to apply for|
|`_requestedRole`|`Role`|The role requested in the committee|
|`_publicKeys`|`MemberRegistrationKeys`|Member public key registration with ECDSA and RSA keys|
|`_fundingUTXO`|`UTXO`|The Bitcoin UTXO that will be used for committee funding|


### unsubscribeFromStream

Unsubscribes from a stream and set as available balance the pre-staked balance


```solidity
function unsubscribeFromStream(StreamDenomination _stream) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_stream`|`StreamDenomination`|The stream denomination to unsubscribe from|


### getCommittee

Gets a committee by its ID


```solidity
function getCommittee(uint128 _committeeId) external view returns (Committee calldata);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_committeeId`|`uint128`|The committee ID|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`Committee`|Committee The complete committee information|


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


### memberRegistry

Gets the member registry contract address


```solidity
function memberRegistry() external view returns (IMemberRegistry);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`IMemberRegistry`|The member registry contract|


### depositAggregatedKey

Allows a member to deposit information  formation

*Called by members to provide their aggregated key for a pending committee*


```solidity
function depositAggregatedKey(uint128 _committeeId, bytes memory _aggregatedKey) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_committeeId`|`uint128`|The ID of the pending committee|
|`_aggregatedKey`|`bytes`|The aggregated public key provided by the member (must be exactly 33 bytes)|


### createCommittee

Triggers the creation of a new committee for a stream if the timeout has expired

*This function is called when the slot usage threshold is reached*


```solidity
function createCommittee(uint64 _streamId) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_streamId`|`uint64`|The stream ID to create a new committee for|


### isPendingCommitteeExpired

Checks if there is a pending committee for the stream and it's expired


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
|`<none>`|`Committee`|Committee The pending committee (contains createdAt and missingData fields)|


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


### depositCommunicationData

Deposits encrypted communication data (IP and Port) for a member in a pending committee

*This function is called by members to provide their encrypted communication data*


```solidity
function depositCommunicationData(uint128 _committeeId, CommunicationData[] memory _communicationData) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_committeeId`|`uint128`|The ID of the pending committee|
|`_communicationData`|`CommunicationData[]`|Array of encrypted communication data (IP and Port) for the member|


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


### setPegManager

Sets the Peg Manager contract address

*Only callable by the contract owner*


```solidity
function setPegManager(IPegManager _pegManager) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_pegManager`|`IPegManager`|The address of the Peg Manager contract|


### setStreamManager

Sets the Stream Manager contract address

*Only callable by the contract owner*


```solidity
function setStreamManager(IStreamManager _streamManager) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_streamManager`|`IStreamManager`|The address of the Stream Manager contract|


### setPendingCommitteeTimeout

Sets the pending committee timeout

*Only callable by the contract owner*


```solidity
function setPendingCommitteeTimeout(uint256 _timeout) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_timeout`|`uint256`|The timeout in seconds for the pending committee|


### setCommitteeMinWatchtowers

Sets the minimum watchtowers required for a committee

*Only callable by the contract owner*


```solidity
function setCommitteeMinWatchtowers(uint256 _minWatchtowers) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_minWatchtowers`|`uint256`|The minimum watchtowers required for a committee|


### setCommitteeMinOperators

Sets the minimum operators required for a committee

*Only callable by the contract owner*


```solidity
function setCommitteeMinOperators(uint256 _minOperators) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_minOperators`|`uint256`|The minimum operators required for a committee|


### setCommitteeMemberCount

Sets the exact number of members required for a committee

*Only callable by the contract owner*


```solidity
function setCommitteeMemberCount(uint256 _committeeMemberCount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_committeeMemberCount`|`uint256`|The exact number of members required for a committee|


### getOperatorTakeAddress

Gets the operator take address for a specific committee


```solidity
function getOperatorTakeAddress(uint128 committeeId, SignatureData[] calldata signatureData)
    external
    returns (address);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`committeeId`|`uint128`|The ID of the committee|
|`signatureData`|`SignatureData[]`|The signature data for the committee members|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The operator take address|


### releaseCommittee

Release the committee members from a packet (return or reapply staked money)


```solidity
function releaseCommittee(uint64 _streamId, uint64 _packetNumber) external;
```

## Events
### NewCommittee
Event emitted when a new committee is created


```solidity
event NewCommittee(uint128 indexed committeeId, Committee _committee);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`committeeId`|`uint128`|The ID of the newly created committee|
|`_committee`|`Committee`|The committee information|

### NewPendingCommittee
Event emitted when a new pending committee is created


```solidity
event NewPendingCommittee(uint128 indexed committeeId, Committee _committee);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`committeeId`|`uint128`|The stream ID for the pending committee|
|`_committee`|`Committee`|The pending committee information|

### PendingCommitteeTimeoutUpdated
Event emitted when pending committee timeout is updated


```solidity
event PendingCommitteeTimeoutUpdated(uint256 timeout);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`timeout`|`uint256`|The new timeout value|

### StreamManagerUpdated
Event emitted when stream manager address is updated


```solidity
event StreamManagerUpdated(address streamManager);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`streamManager`|`address`|The new stream manager address|

### PegManagerUpdated
Event emitted when peg manager address is updated


```solidity
event PegManagerUpdated(address pegManager);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`pegManager`|`address`|The new peg manager address|

### CommitteeMinWatchtowersUpdated
Event emitted when minimum watchtowers requirement is updated


```solidity
event CommitteeMinWatchtowersUpdated(uint256 minWatchtowers);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`minWatchtowers`|`uint256`|The new minimum watchtowers requirement|

### CommitteeMinOperatorsUpdated
Event emitted when minimum operators requirement is updated


```solidity
event CommitteeMinOperatorsUpdated(uint256 minOperators);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`minOperators`|`uint256`|The new minimum operators requirement|

### CommitteeMemberCountUpdated
Event emitted when minimum members requirement is updated


```solidity
event CommitteeMemberCountUpdated(uint256 minMembers);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`minMembers`|`uint256`|The new minimum members requirement|

### MemberInfoDeposited
Event emitted when member info is deposited for committee formation


```solidity
event MemberInfoDeposited(uint128 indexed committeeId, address indexed member, bytes aggregatedKey);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`committeeId`|`uint128`|The ID of the pending committee|
|`member`|`address`|The member's address|
|`aggregatedKey`|`bytes`|The aggregated key provided by the member|

### NoRemainingHonestOperators
Event emitted when no honest operators remain in a committee


```solidity
event NoRemainingHonestOperators(uint128 committeeId);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`committeeId`|`uint128`|The ID of the committee with no honest operators|

### MemberCommunicationDataDeposited
Event emitted when a member has deposited their communication data

*The communication data are encrypted IP's and Port's for each member in the committee*


```solidity
event MemberCommunicationDataDeposited(
    uint128 indexed _committeeId, address indexed member, CommunicationData[] communicationData
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_committeeId`|`uint128`|The ID of the committee for which the member deposited data|
|`member`|`address`|The address of the member who deposited the data|
|`communicationData`|`CommunicationData[]`|The encrypted communication data deposited by the member|

### AllCommunicationDataReady
Event emitted when all committee members have deposited their communication data


```solidity
event AllCommunicationDataReady(uint128 indexed _committeeId);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_committeeId`|`uint128`|The ID of the committee for which all communication data is ready|

## Errors
### CommitteeIsNotPending
Thrown when a committee is not in pending state


```solidity
error CommitteeIsNotPending(uint128 committeeId);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`committeeId`|`uint128`|The ID of the committee that is not pending|

### PendingCommitteeNotExpired
Thrown when a pending committee is not expired


```solidity
error PendingCommitteeNotExpired(uint64 streamId, uint256 createdAt, uint256 expireAt);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`streamId`|`uint64`|The stream ID|
|`createdAt`|`uint256`|The creation timestamp|
|`expireAt`|`uint256`|The expiration timestamp|

### InvalidAggregatedKeyLength
Error thrown when the aggregated key has an invalid length


```solidity
error InvalidAggregatedKeyLength(uint256 length, uint256 expected);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`length`|`uint256`|The actual length provided|
|`expected`|`uint256`|The expected length (33 bytes)|

### InvalidAggregatedKeyZero
Error thrown when the aggregated key is all zeros


```solidity
error InvalidAggregatedKeyZero();
```

### MemberNotInCommittee
Thrown when a member is not in the committee


```solidity
error MemberNotInCommittee(uint128 committeeId, address memberAddress);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`committeeId`|`uint128`|The committee ID|
|`memberAddress`|`address`|The member's address|

### MemberInfoAlreadyDeposited
Thrown when member info is already deposited


```solidity
error MemberInfoAlreadyDeposited(uint128 committeeId, address memberAddress);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`committeeId`|`uint128`|The committee ID|
|`memberAddress`|`address`|The member's address|

### CommitteeNotFound
Thrown when a committee is not found


```solidity
error CommitteeNotFound(uint128 committeeId);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`committeeId`|`uint128`|The committee ID|

### UnauthorizedAccount
Thrown when an account is not authorized


```solidity
error UnauthorizedAccount(address account);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|The unauthorized account|

### InvalidZeroAddress
Thrown when an address is zero


```solidity
error InvalidZeroAddress();
```

### InvalidZeroValue
Thrown when a value is zero


```solidity
error InvalidZeroValue();
```

### InvalidMinMembers
Thrown when minimum members requirement is invalid


```solidity
error InvalidMinMembers(uint256 minMembers, uint256 minCommitteWatchtowers, uint256 minCommitteOperators);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`minMembers`|`uint256`|The minimum members requirement|
|`minCommitteWatchtowers`|`uint256`|The minimum watchtowers requirement|
|`minCommitteOperators`|`uint256`|The minimum operators requirement|

### InvalidMinOperators
Thrown when minimum operators requirement is invalid


```solidity
error InvalidMinOperators(uint256 minMembers, uint256 minCommitteWatchtowers, uint256 minCommitteOperators);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`minMembers`|`uint256`|The minimum members requirement|
|`minCommitteWatchtowers`|`uint256`|The minimum watchtowers requirement|
|`minCommitteOperators`|`uint256`|The minimum operators requirement|

### InvalidMinWatchtowers
Thrown when minimum watchtowers requirement is invalid


```solidity
error InvalidMinWatchtowers(uint256 minMembers, uint256 minCommitteWatchtowers, uint256 minCommitteOperators);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`minMembers`|`uint256`|The minimum members requirement|
|`minCommitteWatchtowers`|`uint256`|The minimum watchtowers requirement|
|`minCommitteOperators`|`uint256`|The minimum operators requirement|

### MemberIsInPendingCommittee
Thrown when a member is already in a pending committee


```solidity
error MemberIsInPendingCommittee(address memberAddress, StreamDenomination denomination);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`memberAddress`|`address`|The member's address|
|`denomination`|`StreamDenomination`|The stream denomination|

### TakeOperatorNotFound
Thrown when no eligible operator is found for take operations


```solidity
error TakeOperatorNotFound(uint128 committeeId);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`committeeId`|`uint128`|The ID of the committee where no operator was found|

### InvalidCommunicationDataLength
Thrown when the number of submitted communication data entries does not match the committee size


```solidity
error InvalidCommunicationDataLength(uint256 providedLength, uint256 expectedLength);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`providedLength`|`uint256`|The actual length of the submitted communication data array|
|`expectedLength`|`uint256`|The expected number of entries (i.e., committee size)|

### InvalidZeroCommunicationData
Thrown when a member submits an empty communication data entry for another member


```solidity
error InvalidZeroCommunicationData(uint256 index, CommunicationData communicationData);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`index`|`uint256`|The index of the communication data entry|
|`communicationData`|`CommunicationData`|The invalid communication data submitted|

### InvalidNonZeroCommunicationData
Thrown when a member submits non-zero communication data for their own slot


```solidity
error InvalidNonZeroCommunicationData(uint256 index, CommunicationData communicationData);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`index`|`uint256`|The index in the array corresponding to the submitting member|
|`communicationData`|`CommunicationData`|The non-zero data submitted in the member's own slot|

### MemberAlreadyDepositedCommunicationData
Thrown when a member attempts to deposit communication data more than once


```solidity
error MemberAlreadyDepositedCommunicationData(
    uint128 committeeId, address memberAddress, uint256 communicationDataLenght
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`committeeId`|`uint128`|The ID of the committee|
|`memberAddress`|`address`|The address of the member attempting a second deposit|
|`communicationDataLenght`|`uint256`|The number of communication data entries already stored|

