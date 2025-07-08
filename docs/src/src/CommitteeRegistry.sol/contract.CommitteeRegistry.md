# CommitteeRegistry
[Git Source](https://github.com/FairgateLabs/bitvmx-union-bridge-contracts/blob/88ae00b3e8fb636de955be6f15b3c84ce2cc3729/src/CommitteeRegistry.sol)

**Inherits:**
[ICommitteeRegistry](/src/interfaces/ICommitteeRegistry.sol/interface.ICommitteeRegistry.md), [BaseProxy](/src/BaseProxy.sol/abstract.BaseProxy.md)

Manages registration, application, and selection of committee members for the union bridge system

*Handles member registration, role assignment, committee formation, staking, and candidate management for all streams*


## State Variables
### members
Mapping of member addresses to their member data


```solidity
mapping(address => Member) internal members;
```


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


### minCommitteeMembers
Minimum number of members required for a committee


```solidity
uint256 public minCommitteeMembers;
```


### pendingCommittees
Mapping of streamId to pending committee data


```solidity
mapping(uint64 streamId => PendingCommittee) internal pendingCommittees;
```


### committeesById
Mapping of committeeId to committee data


```solidity
mapping(uint256 committeeId => Committee) internal committeesById;
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


### pendingCommitteeTimeout
Timeout in seconds for pending committee formation


```solidity
uint256 public pendingCommitteeTimeout;
```


### committeesCandidates
Mapping of stream denomination and role to list of candidate addresses


```solidity
mapping(StreamDenomination denomination => mapping(Role role => address[] membersAddress)) internal committeesCandidates;
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


### _initMemberBalance


```solidity
function _initMemberBalance(Member storage _member) internal;
```

### _getMemberTakePubKey


```solidity
function _getMemberTakePubKey(address _address) internal view returns (bytes32);
```

### _getMemberComPubKey


```solidity
function _getMemberComPubKey(address _address) internal view returns (bytes32);
```

### _getOrRegisterMember


```solidity
function _getOrRegisterMember(address _address, PublicKeyRegistration[] calldata _publicKeys)
    internal
    returns (Member storage);
```

### applyToStream

Applies to participate in a stream with a specific role

*Registers public keys and deposits required bond for the requested role*


```solidity
function applyToStream(StreamDenomination _stream, Role _role, PublicKeyRegistration[] calldata _publicKeys)
    external
    payable;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_stream`|`StreamDenomination`|The stream denomination to apply for|
|`_role`|`Role`|The role requested in the committee|
|`_publicKeys`|`PublicKeyRegistration[]`|Array of public key registrations for TAKE, COVENANT, and COMMUNICATION|


### _committeesCandidatesHasSpace


```solidity
function _committeesCandidatesHasSpace(StreamDenomination _denomination, Role _role) internal view returns (bool);
```

### _registerCandidateToStream


```solidity
function _registerCandidateToStream(
    address _memberAddress,
    StreamDenomination _denomination,
    Role _role,
    uint256 _amount
) internal;
```

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

### _unsubscribeFromStream


```solidity
function _unsubscribeFromStream(address _memberAddress, StreamDenomination _denomination) internal;
```

### _movePreStakedToAvailable


```solidity
function _movePreStakedToAvailable(Member storage _member, address _memberAddress, StreamDenomination _denomination)
    internal;
```

### _movePreStakedToStaked


```solidity
function _movePreStakedToStaked(address _memberAddress, StreamDenomination _denomination, uint64 _packetNumber)
    internal
    returns (Role);
```

### _removeCandidatesAndUpdateBalance


```solidity
function _removeCandidatesAndUpdateBalance(
    CommitteeMember[] memory _members,
    StreamDenomination _denomination,
    uint64 _packetNumber
) internal;
```

### _removeFromCandidates


```solidity
function _removeFromCandidates(address _memberAddress, StreamDenomination _stream, Role _role) internal;
```

### withdrawAvailableBalance

Withdraws available balance to the caller's address

*Can only withdraw balance that is not pre-staked or staked*


```solidity
function withdrawAvailableBalance() external;
```

### _getAddressFromPublicKey


```solidity
function _getAddressFromPublicKey(bytes memory _uncompressedPublicKey) internal pure returns (address);
```

### _validatePublicKeys


```solidity
function _validatePublicKeys(PublicKeyRegistration[] calldata _publicKeys) internal pure;
```

### _registerMember


```solidity
function _registerMember(address _memberAddress, PublicKeyRegistration[] calldata _publicKeys)
    internal
    returns (Member storage);
```

### _registerCommittee


```solidity
function _registerCommittee(uint256 _committeeId, Committee storage _committee) internal;
```

### getCommittee

Gets a committee by its ID


```solidity
function getCommittee(uint256 _committeeId) external view returns (Committee memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_committeeId`|`uint256`|The committee ID|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`Committee`|Committee The complete committee information|


### _getCommittee


```solidity
function _getCommittee(uint256 _committeeId) internal view returns (Committee storage);
```

### getCommitteeMembers

Gets all members of a specific committee


```solidity
function getCommitteeMembers(uint256 _committeeId) external view returns (CommitteeMember[] memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_committeeId`|`uint256`|The committee ID|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`CommitteeMember[]`|Array of committee members with their roles|


### _getCommitteeMembers


```solidity
function _getCommitteeMembers(uint256 _committeeId) internal view returns (CommitteeMember[] memory);
```

### getMemberTakePubKey

Gets the TAKE public key for a specific member


```solidity
function getMemberTakePubKey(address _address) external view returns (bytes32);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_address`|`address`|The member's address|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|The TAKE public key (x-coordinate only)|


### getMemberComPubKey

Gets the COMMUNICATION public key for a specific member


```solidity
function getMemberComPubKey(address _address) external view returns (bytes32);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_address`|`address`|The member's address|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|The COMMUNICATION public key (x-coordinate only)|


### getMemberPublicKeys

Retrieves all public keys for a specific member


```solidity
function getMemberPublicKeys(address _address) external view returns (bytes32[] memory publicKeys);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_address`|`address`|The member's address|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`publicKeys`|`bytes32[]`|Array of public keys indexed by PublicKeyIndex|


### _getMemberApplicationData


```solidity
function _getMemberApplicationData(address _address, StreamDenomination _denomination)
    internal
    view
    returns (ApplicationData storage);
```

### getMemberRequestedRole

Gets the requested role for a member in a specific stream


```solidity
function getMemberRequestedRole(address _memberAddress, StreamDenomination _denomination)
    external
    view
    returns (Role);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_memberAddress`|`address`|The member's address|
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
function getMemberPreStakedBalance(address _memberAddress, StreamDenomination _denomination)
    external
    view
    returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_memberAddress`|`address`|The member's address|
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


### _getMember


```solidity
function _getMember(address _address) internal view returns (Member storage member);
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

### depositAggregatedKey

Allows a member to deposit information for committee formation

*Called by members to provide their aggregated key for a pending committee*


```solidity
function depositAggregatedKey(uint64 _streamId, bytes32 _aggregatedKey) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_streamId`|`uint64`|The stream ID for the pending committee|
|`_aggregatedKey`|`bytes32`|The aggregated public key provided by the member|


### depositCommunicationData


```solidity
function depositCommunicationData(uint64 _streamId, CommunicationData[] memory _communicationData) external;
```

### getMemberCommunicationData

Gets the encrypted communication data for one member in a committee

*This function returns the encrypted communication data (IP and Port) deposited for a particular member*

*The order of the data corresponds to the order of members in the committee*


```solidity
function getMemberCommunicationData(uint64 _streamId, address _memberAddress)
    external
    view
    returns (CommunicationData[] memory communicationData);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_streamId`|`uint64`|The stream ID for the committee|
|`_memberAddress`|`address`|The address of the member we are requesting data for|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`communicationData`|`CommunicationData[]`|encrypted communication data (IP and Port) from the committee members|


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


### getMissingCommunicationDataCount

Returns the number of members that have not deposited their communication data yet


```solidity
function getMissingCommunicationDataCount(uint64 _streamId) external view returns (uint16 missingCommunicationData);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_streamId`|`uint64`|The stream ID to get the missing communication data count for|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`missingCommunicationData`|`uint16`|The number of members that have not deposited their communication data yet|


### _getPendingCommittee


```solidity
function _getPendingCommittee(uint64 _streamId) internal view returns (PendingCommittee storage pendingCommittee);
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


### _selectCommittee

Randomly selects members to form a new committee for a given stream

*Pseudo-randomly select at least minCommitteeWatchtowers watchtowers and minCommitteeOperators operators.
- reverts with notEnoughWatchtowers if there are fewer than minCommitteeWatchtowers watchtower candidates
- reverts with notEnoughOperators if there are fewer than minCommitteeOperators operator candidates*


```solidity
function _selectCommittee(uint64 _streamId) internal returns (CommitteeMember[] memory, PendingCommitteeStatus);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_streamId`|`uint64`|The ID of the stream to select committee members for (0-4)|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`CommitteeMember[]`|An array of minCommitteeMembers CommitteeMembers containing the selected members.|
|`<none>`|`PendingCommitteeStatus`||


### getOperatorTakeAddress

Gets the next available operator address for take operations

*Rotates through committee operators to distribute take responsibilities*

*Only operators who have deposited their signatures nonces are eligible for take operations*

*Reverts with TakeOperatorNotFound if no eligible operator is found*


```solidity
function getOperatorTakeAddress(uint256 _committeeId, SignatureData[] calldata _signatureData)
    external
    onlyPegManager
    returns (address);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_committeeId`|`uint256`|The committee ID to get the operator from|
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


### setCommitteeMinMembers

Sets the minimum members required for a committee

*Only callable by the contract owner*


```solidity
function setCommitteeMinMembers(uint256 _minMembers) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_minMembers`|`uint256`|The minimum number of members required for a committee|


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


### _reapplyToStream


```solidity
function _reapplyToStream(address _memberAddress, StreamDenomination _denomination, uint64 _packetNumber, Role _role)
    internal;
```

### _moveStakedToAvailable


```solidity
function _moveStakedToAvailable(address _memberAddress, StreamDenomination _denomination, uint64 _packetNumber)
    internal;
```

### setReApplyForStream

Sets the reapply flag for a member in a specific stream

*Controls whether the member will automatically reapply after committee release*


```solidity
function setReApplyForStream(StreamDenomination _denomination, bool _reApply) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_denomination`|`StreamDenomination`|The stream denomination to set the flag for|
|`_reApply`|`bool`|True to automatically reapply, false to receive balance as available|


### getReApplyForStream

Gets the reapply flag for a member in a specific stream


```solidity
function getReApplyForStream(StreamDenomination _denomination) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_denomination`|`StreamDenomination`|The stream denomination to check|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if the member will automatically reapply, false otherwise|


### onlyPegManager

Modifier to restrict access to the PegManager contract

*Reverts if the caller is not the PegManager*


```solidity
modifier onlyPegManager();
```

### _onlyPegManager


```solidity
function _onlyPegManager(address _account) internal view;
```

