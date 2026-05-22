# CommitteeRegistry
[Git Source](https://github.com/temp-rsk/bitvmx-union-bridge-contracts/blob/bd6b4a28bf5973e554d9b7a237190a44cdd46b38/src/CommitteeRegistry.sol)

**Inherits:**
[ICommitteeRegistry](/src/interfaces/ICommitteeRegistry.sol/interface.ICommitteeRegistry.md), [BaseProxy](/src/BaseProxy.sol/abstract.BaseProxy.md), ReentrancyGuardUpgradeable, [Pausable](/src/Pausable.sol/abstract.Pausable.md)

Manages committee formation, selection, and lifecycle for the union bridge system

*Handles committee creation, pending committee management, and coordination with MemberRegistry*


## State Variables
### whitelisted
Mapping of whitelisted addresses


```solidity
mapping(address => bool) internal whitelisted;
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


### committeeMemberCount
Minimum number of members required for a committee


```solidity
uint256 public committeeMemberCount;
```


### pendingCommittees
Mapping of streamId to the pending committee id


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


### whitelister
Whitelister for managing whitelisted addresses


```solidity
address public whitelister;
```


### streamManager
Stream manager contract for managing streams and packets


```solidity
IStreamManager streamManager;
```


### memberRegistry
Member registry contract for member management


```solidity
IMemberRegistry public memberRegistry;
```


### accessManager
Access manager contract for access control


```solidity
IAccessManager public accessManager;
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
function initialize(
    address _initialOwner,
    IAccessManager _accessManager,
    IMemberRegistry _memberRegistry,
    IStreamManager _streamManager,
    CommitteeRegistrySettings memory _settings
) public virtual initializer;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_initialOwner`|`address`|The initial owner of the contract|
|`_accessManager`|`IAccessManager`||
|`_memberRegistry`|`IMemberRegistry`|The member registry contract address|
|`_streamManager`|`IStreamManager`||
|`_settings`|`CommitteeRegistrySettings`|The settings for the committee registry|


### _revertIfZero


```solidity
function _revertIfZero(uint256 _value) internal pure;
```

### isWhitelisted

Checks if an address is whitelisted


```solidity
function isWhitelisted(address _address) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_address`|`address`|The address to check|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if the address is whitelisted, false otherwise|


### whitelistAddress

Whitelists an address to enable it to apply to a stream

*Only callable by the contract whitelister*


```solidity
function whitelistAddress(address _address) external onlyWhitelister;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_address`|`address`|The address to whitelist|


### whitelistAddresses

Whitelists multiple addresses to enable them to apply to a stream

*Only callable by the contract whitelister*


```solidity
function whitelistAddresses(address[] memory _addresses) external onlyWhitelister;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_addresses`|`address[]`|The addresses to whitelist|


### _whitelistAddresses


```solidity
function _whitelistAddresses(address[] memory _addresses) internal;
```

### _whitelistAddress


```solidity
function _whitelistAddress(address _addressToWhitelist) internal;
```

### unwhitelistAddress

Unwhitelists an address to disable it from applying to a stream

*Only callable by the contract whitelister*


```solidity
function unwhitelistAddress(address _address) external onlyWhitelister;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_address`|`address`|The address to unwhitelist|


### unwhitelistAddresses

Unwhitelists multiple addresses to disable them from applying to a stream

*Only callable by the contract whitelister*


```solidity
function unwhitelistAddresses(address[] memory _addresses) external onlyWhitelister;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_addresses`|`address[]`|The addresses to unwhitelist|


### _unwhitelistAddresses


```solidity
function _unwhitelistAddresses(address[] memory _addressesToUnwhitelist) internal;
```

### _processUnwhitelisting


```solidity
function _processUnwhitelisting(address _addressToUnwhitelist, bool[] memory _pendingCommitteesRestarted) internal;
```

### _cleanupAfterUnwhitelisting


```solidity
function _cleanupAfterUnwhitelisting(address _addressToUnwhitelist, bool[] memory _pendingCommitteesRestarted)
    internal;
```

### _restartPendingCommitteesAfterUnwhitelisting


```solidity
function _restartPendingCommitteesAfterUnwhitelisting(
    address _addressToUnwhitelist,
    bool[] memory _pendingCommitteesRestarted
) internal;
```

### _cleanUpMembershipAfterUnwhitelisting


```solidity
function _cleanUpMembershipAfterUnwhitelisting(address _addressToUnwhitelist) internal;
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
) external payable nonReentrant whenNotPaused onlyWhitelistedAddress;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_stream`|`StreamDenomination`||
|`_role`|`Role`||
|`_publicKeys`|`MemberRegistrationKeys`|Member public key registration with ECDSA and RSA hash keys|
|`_fundingUTXO`|`UTXO`|The Bitcoin UTXO that will be used for committee funding|


### unsubscribeFromStream

Unsubscribes from a stream and sets the pre-staked balance as available

*Only callable when contract is unpaused*


```solidity
function unsubscribeFromStream(StreamDenomination _denomination) external whenNotPaused;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_denomination`|`StreamDenomination`|The stream denomination to unsubscribe from|


### _unsubscribeFromStream


```solidity
function _unsubscribeFromStream(address _sender, StreamDenomination _denomination) internal;
```

### _isSubscribedToStream


```solidity
function _isSubscribedToStream(address _userAddress, StreamDenomination _denomination) internal view returns (bool);
```

### _isInPendingCommittee


```solidity
function _isInPendingCommittee(address _memberAddress, StreamDenomination _denomination) internal view returns (bool);
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


### _getCommitteeId


```solidity
function _getCommitteeId(uint64 _streamId, uint64 _nonce) internal pure returns (uint128);
```

### getCommitteeTakePubKey

Retrieves the committee take aggregated public key for a specific packet


```solidity
function getCommitteeTakePubKey(uint128 _committeeId) external view returns (bytes memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_committeeId`|`uint128`|The committee ID|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes`|bytes The committee take aggregated public key for this packet (33 bytes compressed format)|


### getCommitteeDisputePubKey

Retrieves the committee dispute aggregated public key for a specific packet


```solidity
function getCommitteeDisputePubKey(uint128 _committeeId) external view returns (bytes memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_committeeId`|`uint128`|The committee ID|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes`|bytes The committee dispute aggregated public key for this packet (33 bytes compressed format)|


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


### getCommitteeMembersLength

Gets the number of members in a specific committee


```solidity
function getCommitteeMembersLength(uint128 _committeeId) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_committeeId`|`uint128`|The committee ID|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The number of committee members (e.g. for validating input-not-revealed tx output count)|


### _getCommitteeMembers


```solidity
function _getCommitteeMembers(uint128 _committeeId) internal view returns (CommitteeMember[] memory);
```

### restartPendingCommittee

Restarts a pending committee if it has expired

*Only callable when contract is unpaused*


```solidity
function restartPendingCommittee(uint64 _streamId) external whenNotPaused;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_streamId`|`uint64`|The stream ID to restart the pending committee for|


### _restartPendingCommittee


```solidity
function _restartPendingCommittee(uint64 _streamId) internal;
```

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

### _getMemberCommitteeData


```solidity
function _getMemberCommitteeData(uint128 _committeeId, address _memberAddress)
    internal
    view
    returns (PendingCommitteeData storage memberCommitteeData);
```

### validateMemberInCommittee

Validates that a member is part of a specific committee; reverts if not


```solidity
function validateMemberInCommittee(uint128 _committeeId, address _memberAddress) external view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_committeeId`|`uint128`|The committee ID|
|`_memberAddress`|`address`|The address of the member to check|


### depositAggregatedKeys

Allows a member to deposit their aggregated keys for committee formation

*Called by members to provide their take and dispute aggregated keys for a pending committee*


```solidity
function depositAggregatedKeys(
    uint128 _committeeId,
    bytes memory _takeAggregatedKey,
    bytes memory _disputeAggregatedKey
) external whenNotPaused;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_committeeId`|`uint128`|The ID of the pending committee|
|`_takeAggregatedKey`|`bytes`|The take aggregated public key provided by the member (must be exactly 33 bytes)|
|`_disputeAggregatedKey`|`bytes`|The dispute aggregated public key provided by the member (must be exactly 33 bytes)|


### _validateAggregatedKey


```solidity
function _validateAggregatedKey(bytes memory _aggregatedKey) internal pure;
```

### _setMemberCommitteeData


```solidity
function _setMemberCommitteeData(
    PendingCommitteeData storage memberCommitteeData,
    bytes memory _takeAggregatedKey,
    bytes memory _disputeAggregatedKey
) internal;
```

### depositCommunicationData

Deposits encrypted communication data (IP and Port) for a member in a pending committee

*This function is called by members to provide their encrypted communication data*


```solidity
function depositCommunicationData(uint128 _committeeId, CommunicationData[] memory _communicationData)
    external
    whenNotPaused;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_committeeId`|`uint128`|The ID of the pending committee|
|`_communicationData`|`CommunicationData[]`|Array of encrypted communication data (IP and Port) for the member|


### getMemberCommunicationData

Gets the encrypted communication data for one member in a committee

*This function returns the encrypted communication data (IP and Port) deposited for a particular member*


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


### _resetPendingCommittee


```solidity
function _resetPendingCommittee(uint64 _streamId) internal;
```

### _discardPendingCommittee


```solidity
function _discardPendingCommittee(uint64 _streamId) internal;
```

### selectTakeOperator

Gets the operator dispute data (address and dispute public key) for operator-take operations

*Rotates through committee operators to distribute take responsibilities*


```solidity
function selectTakeOperator(uint128 _committeeId, SignatureData[] calldata _signatureData, uint8 _missingNonces)
    external
    returns (address operatorAddress, CompactPubKey memory disputePubKey, CompactPubKey memory takePubKey);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_committeeId`|`uint128`|The committee ID to get the operator from|
|`_signatureData`|`SignatureData[]`|Array of signature data for committee members|
|`_missingNonces`|`uint8`|Number of missing nonces|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`operatorAddress`|`address`|The address of the next available operator for take operations|
|`disputePubKey`|`CompactPubKey`|The operator's dispute public key|
|`takePubKey`|`CompactPubKey`|The operator's take public key|


### onlyWhitelister

Modifier to restrict access to the whitelister

*Reverts if the caller is not the whitelister*


```solidity
modifier onlyWhitelister();
```

### _onlyWhitelister


```solidity
function _onlyWhitelister(address _sender) internal view virtual;
```

### onlyWhitelistedAddress


```solidity
modifier onlyWhitelistedAddress();
```

### _onlyWhitelistedAddress


```solidity
function _onlyWhitelistedAddress(address _sender) internal view virtual;
```

### setWhitelister

Sets the Whitelister address

*Only callable by the contract owner*


```solidity
function setWhitelister(address _newWhitelister) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_newWhitelister`|`address`|The address of the whitelister|


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


### demoteOperatorToWatchtower

Demotes an operator to watchtower in a specific active committee

*Only callable by the contract owner*


```solidity
function demoteOperatorToWatchtower(uint128 _committeeId, address _memberAddress) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_committeeId`|`uint128`|The ID of the active committee|
|`_memberAddress`|`address`|The address of the operator to demote|


### releaseCommittee

Releases committee members from a packet and handles their staked balance

*Called by PegManager to release committee members after packet completion*


```solidity
function releaseCommittee(uint64 _streamId, uint64 _packetNumber) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_streamId`|`uint64`|The stream ID for the committee|
|`_packetNumber`|`uint64`|The packet number where the committee was active|


### getCommitteeDisputeKeys

Gets the dispute keys for all committee members


```solidity
function getCommitteeDisputeKeys(uint128 _committeeId) external view returns (CompactPubKey[] memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_committeeId`|`uint128`|The committee ID|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`CompactPubKey[]`|Array of dispute keys for all members|


### _getCommitteeDisputeKeys


```solidity
function _getCommitteeDisputeKeys(uint128 _committeeId) internal view returns (CompactPubKey[] memory);
```

### forceDiscardPendingCommittee_TESTNET

Forces a discard of a pending committee, and enables the creation of a new committee

*Only callable on testnet*


```solidity
function forceDiscardPendingCommittee_TESTNET(uint64 _streamId) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_streamId`|`uint64`|The stream ID for the pending committee to discard|


