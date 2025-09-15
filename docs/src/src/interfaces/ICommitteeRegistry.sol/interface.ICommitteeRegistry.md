# ICommitteeRegistry
[Git Source](https://github.com/FairgateLabs/bitvmx-union-bridge-contracts/blob/9f14e34a8636f5a1e820830e7bebc3a177006c7a/src/interfaces/ICommitteeRegistry.sol)

Interface for managing committee formation, lifecycle, and coordination in the union bridge

*This interface provides functions for committee formation, committee data management,*

*and coordination with the MemberRegistry for member operations*

*Note: Member registration and balance management functions have been moved to IMemberRegistry*


## Functions
### applyToStream

Applies to a stream with a specified role and public keys

*Delegates member registration to MemberRegistry while handling validation and committee creation triggers*

*Validates public keys and coordinates with MemberRegistry for member registration and candidacy*


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
|----|----|--------------|
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


### memberRegistry

Gets the MemberRegistry contract instance

*Returns the contract responsible for member management operations*


```solidity
function memberRegistry() external view returns (IMemberRegistry);
```

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`IMemberRegistry`|The MemberRegistry contract instance|


### withdrawAvailableBalance

Withdraws available balance to the caller's address

*Can only withdraw balance that is not pre-staked or staked*


```solidity
function withdrawAvailableBalance() external;
```

### getMemberPublicKeys

Retrieves all public keys for a specific member


```solidity
function getMemberPublicKeys(address _address) external view returns (MemberKeys memory publicKeys);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_address`|`address`|The member's address|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`publicKeys`|`MemberKeys`|Member public keys structure|


### getMemberRequestedRole

Gets the requested role for a member in a specific stream


```solidity
function getMemberRequestedRole(address _address, StreamDenomination _denomination) external view returns (Role);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_address`|`address`|The member's address|
|`_denomination`|`StreamDenomination`|The stream denomination|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`Role`|The requested role for the member|


### getMemberAvailableBalance

Gets the available balance for a member


```solidity
function getMemberAvailableBalance(address _address) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_address`|`address`|The member's address|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The available balance that can be withdrawn|


### getMemberPreStakedBalance

Gets the pre-staked balance for a member in a specific stream


```solidity
function getMemberPreStakedBalance(address _address, StreamDenomination _denomination)
    external
    view
    returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_address`|`address`|The member's address|
|`_denomination`|`StreamDenomination`|The stream denomination|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The pre-staked balance for the stream|


### getMemberStakedBalance

Gets the staked balance for a member in a specific stream and packet


```solidity
function getMemberStakedBalance(address _address, StreamDenomination _denomination, uint64 _packetNumber)
    external
    view
    returns (uint256 amount);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_address`|`address`|The member's address|
|`_denomination`|`StreamDenomination`|The stream denomination|
|`_packetNumber`|`uint64`|The packet number|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|The staked amount in the packet|


### getMemberFundingUTXO

Gets the funding UTXO for a member in a specific stream


```solidity
function getMemberFundingUTXO(uint64 _streamId, address _memberAddress) external view returns (UTXO memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_streamId`|`uint64`|The stream ID|
|`_memberAddress`|`address`|The member's address|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`UTXO`|The funding UTXO for the member's application to the stream|


### getCommitteeCandidates

Gets all candidates for a specific role in a stream


```solidity
function getCommitteeCandidates(StreamDenomination _denomination, Role _role)
    external
    view
    returns (address[] memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_denomination`|`StreamDenomination`|The stream denomination|
|`_role`|`Role`|The role to get candidates for|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address[]`|Array of candidate addresses|


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


### getMemberTakePubKey

Gets the TAKE public key for a specific member


```solidity
function getMemberTakePubKey(address _memberAddress) external view returns (bytes32);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_memberAddress`|`address`|The member's address|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|The TAKE public key (x-coordinate only)|


### getMemberComPubKey

Gets the COMMUNICATION public key for a specific member


```solidity
function getMemberComPubKey(address _address) external view returns (RSAPublicKey memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_address`|`address`|The member's address|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`RSAPublicKey`|RSAPublicKey The RSA COMMUNICATION public key|


### depositAggregatedKey

Allows a member to deposit information  formation

*Called by members to provide their aggregated key for a pending committee*


```solidity
function depositAggregatedKey(uint128 _committeeId, bytes32 _aggregatedKey) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_committeeId`|`uint128`|The ID of the pending committee|
|`_aggregatedKey`|`bytes32`|The aggregated public key provided by the member|


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
function getPendingCommittee(uint64 _streamId)
    external
    view
    returns (Committee memory committee, uint256 createdAt, uint256 missingData);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_streamId`|`uint64`|The stream ID to get the pending committee for|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`committee`|`Committee`|The pending committee|
|`createdAt`|`uint256`|The timestamp when the pending committee was created|
|`missingData`|`uint256`|The number of members that have not provided their data yet|


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

### setReApplyForStream

Set the ReApply flag for a stream


```solidity
function setReApplyForStream(StreamDenomination _denomination, bool _reApply) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_denomination`|`StreamDenomination`|The denomination of the stream|
|`_reApply`|`bool`|The reapply flag to set|


### getReApplyForStream

Get the ReApply flag for a stream


```solidity
function getReApplyForStream(StreamDenomination _denomination) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_denomination`|`StreamDenomination`|The denomination of the stream|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|reApply The reapply flag for the stream|


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

### NewMember
Event emitted when a new member is registered


```solidity
event NewMember(address indexed member, MemberKeys publicKeys);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`member`|`address`|The member address|
|`publicKeys`|`MemberKeys`|The public keys of the new member|

### MemberUnsubscribedFromStream
Event emitted when a member unsubscribes from a stream


```solidity
event MemberUnsubscribedFromStream(address indexed member, StreamDenomination stream);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`member`|`address`|The member's address|
|`stream`|`StreamDenomination`|The stream denomination|

### NewAvailableBalance
Event emitted when a member's balance is updated


```solidity
event NewAvailableBalance(address indexed memberAddress, uint256 availableBalance, uint256 preStakedBalance);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`memberAddress`|`address`|The member's address|
|`availableBalance`|`uint256`|The new available balance|
|`preStakedBalance`|`uint256`|The new pre-staked balance|

### AvailableBalanceRetrieved
Event emitted when available balance is withdrawn


```solidity
event AvailableBalanceRetrieved(address indexed sender, uint256 amount);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`sender`|`address`|The address that withdrew the balance|
|`amount`|`uint256`|The amount withdrawn|

### NewSecurityBondDeposit
Event emitted when a security bond is deposited


```solidity
event NewSecurityBondDeposit(
    address indexed sender, StreamDenomination requestedStream, Role requestedRole, uint256 amount
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`sender`|`address`|The address that deposited the bond|
|`requestedStream`|`StreamDenomination`|The stream denomination|
|`requestedRole`|`Role`|The requested role|
|`amount`|`uint256`|The amount deposited|

### MissingWatchtowers
Event emitted when there are not enough watchtowers


```solidity
event MissingWatchtowers(StreamDenomination denomination, uint256 required, uint256 missing);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`denomination`|`StreamDenomination`|The stream denomination|
|`required`|`uint256`|The required number of watchtowers|
|`missing`|`uint256`|The number of missing watchtowers|

### MissingOperators
Event emitted when there are not enough operators


```solidity
event MissingOperators(StreamDenomination denomination, uint256 required, uint256 missing);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`denomination`|`StreamDenomination`|The stream denomination|
|`required`|`uint256`|The required number of operators|
|`missing`|`uint256`|The number of missing operators|

### MissingMembers
Event emitted when there are not enough members


```solidity
event MissingMembers(StreamDenomination denomination, uint256 required, uint256 missing);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`denomination`|`StreamDenomination`|The stream denomination|
|`required`|`uint256`|The required number of members|
|`missing`|`uint256`|The number of missing members|

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
event MemberInfoDeposited(uint128 indexed committeeId, address indexed member, bytes32 aggregatedKey);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`committeeId`|`uint128`|The ID of the pending committee|
|`member`|`address`|The member's address|
|`aggregatedKey`|`bytes32`|The aggregated key provided by the member|

### NoRemainingHonestOperators
Event emitted when no honest operators remain in a committee


```solidity
event NoRemainingHonestOperators(uint128 committeeId);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`committeeId`|`uint128`|The ID of the committee with no honest operators|

### MemberReApplied
Event emitted when a member reapplies to a stream


```solidity
event MemberReApplied(
    address indexed memberAddress, StreamDenomination denomination, Role role, uint256 preStakedBalance
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`memberAddress`|`address`|The member's address|
|`denomination`|`StreamDenomination`|The stream denomination|
|`role`|`Role`|The role requested by the member|
|`preStakedBalance`|`uint256`|The pre-staked balance for the application|

### MemberReApplyUpdated
Event emitted when a member's reapply flag is updated


```solidity
event MemberReApplyUpdated(address indexed memberAddress, StreamDenomination denomination, bool reApply);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`memberAddress`|`address`|The member's address|
|`denomination`|`StreamDenomination`|The stream denomination|
|`reApply`|`bool`|The new reapply flag value|

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
### RequestedDifferentStreamsAndRolesLength
Thrown when streams and roles arrays have different lengths


```solidity
error RequestedDifferentStreamsAndRolesLength(uint256 streamsLength, uint256 rolesLength);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`streamsLength`|`uint256`|The length of the streams array|
|`rolesLength`|`uint256`|The length of the roles array|

### RequestedNoRoles
Thrown when no roles are requested


```solidity
error RequestedNoRoles();
```

### RequestedMultipleRolesForStream
Thrown when multiple roles are requested for the same stream


```solidity
error RequestedMultipleRolesForStream(StreamDenomination stream, Role role1, Role role2);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`stream`|`StreamDenomination`|The stream denomination|
|`role1`|`Role`|The first requested role|
|`role2`|`Role`|The second requested role|

### AlreadyRegisteredMember
Thrown when a member is already registered


```solidity
error AlreadyRegisteredMember(address memberAddress);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`memberAddress`|`address`|The address of the already registered member|

### TooManyMembersPerComitee
Thrown when there are too many members per committee


```solidity
error TooManyMembersPerComitee(uint256 maxMemebersPerCommittee);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`maxMemebersPerCommittee`|`uint256`|The maximum number of members allowed per committee|

### AlreadyRegisteredCommittee
Thrown when a committee is already registered


```solidity
error AlreadyRegisteredCommittee(uint128 committeeId);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`committeeId`|`uint128`|The ID of the already registered committee|

### MemberNotFound
Thrown when a member is not found


```solidity
error MemberNotFound(address memberAddress);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`memberAddress`|`address`|The address of the member not found|

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

### InvalidAggregatedKey
Thrown when the aggregated key is invalid


```solidity
error InvalidAggregatedKey();
```

### RepeatedPublicKeys
Thrown when public keys are repeated


```solidity
error RepeatedPublicKeys(uint256 index, bytes32 publicKeyX, uint256 repeatedIndex, bytes32 repeatedPublicKeyX);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`index`|`uint256`|The index of the first occurrence|
|`publicKeyX`|`bytes32`|The X-coordinate of the public key|
|`repeatedIndex`|`uint256`|The index of the repeated occurrence|
|`repeatedPublicKeyX`|`bytes32`|The X-coordinate of the repeated public key|

### InvalidZeroEDCSAPublicKey
Thrown when a EDCSA public key is zero


```solidity
error InvalidZeroEDCSAPublicKey(PublicKeyType keyType, bytes32 publicKeyX, bytes32 publicKeyY);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`keyType`|`PublicKeyType`|The type of the public key (TAKE, COVENANT, or COMMUNICATION)|
|`publicKeyX`|`bytes32`|The X-coordinate of the public key|
|`publicKeyY`|`bytes32`|The Y-coordinate of the public key|

### InvalidZeroRSAPublicKey
Thrown when a RSA public key is zero


```solidity
error InvalidZeroRSAPublicKey(PublicKeyType keyType);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`keyType`|`PublicKeyType`|The type of the public key (TAKE, COVENANT, or COMMUNICATION)|

### PublicKeyMismatch
Thrown when a public key doesn't match the expected value


```solidity
error PublicKeyMismatch(PublicKeyType keyType, bytes32 currentPubKey, bytes32 newPubKey);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`keyType`|`PublicKeyType`|The type of the public key (TAKE, COVENANT, or COMMUNICATION)|
|`currentPubKey`|`bytes32`|The current public key|
|`newPubKey`|`bytes32`|The new public key|

### InvalidZeroEDCSASignature
Thrown when a signature is zero


```solidity
error InvalidZeroEDCSASignature(PublicKeyType keyType, ECDSAPublicKey publicKey);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`keyType`|`PublicKeyType`|The type of the public key (TAKE, COVENANT, or COMMUNICATION)|
|`publicKey`|`ECDSAPublicKey`|The public key registration with invalid signature|

### InvalidEDCSASignature
Thrown when a signature is invalid


```solidity
error InvalidEDCSASignature(
    PublicKeyType keyType, ECDSAPublicKey publicKey, address recoveredSignerAddress, address signerAddress
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`keyType`|`PublicKeyType`|The type of the public key (TAKE, COVENANT, or COMMUNICATION)|
|`publicKey`|`ECDSAPublicKey`|The public key registration with invalid signature|
|`recoveredSignerAddress`|`address`|The address recovered from the signature|
|`signerAddress`|`address`|The expected signer address|

### NoCommitteeMembers
Thrown when there are no committee members


```solidity
error NoCommitteeMembers();
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

### RequestedNoneRoleForStream
Thrown when no role is requested for a stream


```solidity
error RequestedNoneRoleForStream(StreamDenomination stream);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`stream`|`StreamDenomination`|The stream denomination|

### TooManyMembers
Thrown when there are too many members


```solidity
error TooManyMembers(uint256 maxMembers);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`maxMembers`|`uint256`|The maximum number of members allowed|

### NotEnoughWatchtowers
Thrown when there are not enough watchtowers


```solidity
error NotEnoughWatchtowers(uint64 streamId);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`streamId`|`uint64`|The stream ID|

### NotEnoughOperators
Thrown when there are not enough operators


```solidity
error NotEnoughOperators(uint64 streamId);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`streamId`|`uint64`|The stream ID|

### NotEnoughMembers
Thrown when there are not enough members


```solidity
error NotEnoughMembers(uint64 streamId);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`streamId`|`uint64`|The stream ID|

### MemberAlreadyRegisteredForStream
Thrown when a member is already registered for a stream


```solidity
error MemberAlreadyRegisteredForStream(
    address memberAddress, StreamDenomination requestedStream, Role requestedRole, Role currentRole
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`memberAddress`|`address`|The member's address|
|`requestedStream`|`StreamDenomination`|The requested stream|
|`requestedRole`|`Role`|The requested role|
|`currentRole`|`Role`|The current role|

### MemberIsNotCandidateForStream
Thrown when a member is not a candidate for a stream


```solidity
error MemberIsNotCandidateForStream(address member, StreamDenomination stream);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`member`|`address`|The member's address|
|`stream`|`StreamDenomination`|The stream denomination|

### NoAvailableBalanceToWithdraw
Thrown when there is no available balance to withdraw


```solidity
error NoAvailableBalanceToWithdraw(address member);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`member`|`address`|The member's address|

### MemberNotRegistered
Thrown when a member is not registered


```solidity
error MemberNotRegistered(address memberAddress);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`memberAddress`|`address`|The member's address|

### DespositBondTooLow
Thrown when the deposit bond is too low


```solidity
error DespositBondTooLow(uint256 sent, uint256 minDeposit);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`sent`|`uint256`|The amount sent|
|`minDeposit`|`uint256`|The minimum deposit required|

### FailedToSendRSK
Thrown when RSK transfer fails


```solidity
error FailedToSendRSK(address memberAddress, uint256 amount);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`memberAddress`|`address`|The member's address|
|`amount`|`uint256`|The amount that failed to transfer|

### InvalidZeroValue
Thrown when a value is zero


```solidity
error InvalidZeroValue();
```

### ZeroUTXOTxid
Thrown when the funding UTXO transaction ID is zero


```solidity
error ZeroUTXOTxid(UTXO utxo);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`utxo`|`UTXO`|The complete UTXO with zero transaction ID|

### ZeroUTXOAmount
Thrown when the funding UTXO amount is zero


```solidity
error ZeroUTXOAmount(UTXO utxo);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`utxo`|`UTXO`|The complete UTXO with zero amount|

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

### TooManyCandidatesForStream
Thrown when there are too many candidates for a stream


```solidity
error TooManyCandidatesForStream(StreamDenomination denomination, Role role);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`denomination`|`StreamDenomination`|The stream denomination|
|`role`|`Role`|The role for which there are too many candidates|

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

### _MemberIndexOutOfBounds
Thrown when member index is out of bounds


```solidity
error _MemberIndexOutOfBounds(uint16 memberIndex);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`memberIndex`|`uint16`|The invalid member index|

### _FailedToCreateCommittee
Thrown when committee creation fails


```solidity
error _FailedToCreateCommittee(uint64 streamId, PendingCommitteeStatus status);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`streamId`|`uint64`|The stream ID|
|`status`|`PendingCommitteeStatus`|The status indicating why creation failed|

### _InvalidOperatorTakePubKey
Thrown when a member's take public key doesn't match the signature public key


```solidity
error _InvalidOperatorTakePubKey(
    uint128 committeeId, address memberAddress, bytes32 memberPubKey, bytes32 signaturePubKeyX
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`committeeId`|`uint128`|The ID of the committee|
|`memberAddress`|`address`|The member's address|
|`memberPubKey`|`bytes32`|The member's registered take public key|
|`signaturePubKeyX`|`bytes32`|The public key X-coordinate from the signature|

### _inconsistentPreStakedBalanceAndRole
Thrown when a member's pre-staked balance doesn't match their requested role requirements


```solidity
error _inconsistentPreStakedBalanceAndRole(
    address memberAddress, StreamDenomination denomination, uint256 preStakedBalance, Role requestedRole
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`memberAddress`|`address`|The member's address|
|`denomination`|`StreamDenomination`|The stream denomination|
|`preStakedBalance`|`uint256`|The member's pre-staked balance|
|`requestedRole`|`Role`|The role requested by the member|

