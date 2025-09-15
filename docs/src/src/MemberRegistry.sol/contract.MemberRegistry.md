# MemberRegistry
[Git Source](https://github.com/temp-rsk/bitvmx-union-bridge-contracts/blob/main/src/MemberRegistry.sol)

**Inherits:**
[IMemberRegistry](/src/interfaces/IMemberRegistry.sol/interface.IMemberRegistry.md), [BaseProxy](/src/BaseProxy.sol/abstract.BaseProxy.md)

Manages member registration, applications, and balance tracking for the union bridge system

*Handles member lifecycle operations including registration, candidacy, and balance management*

*This contract was split from the original CommitteeRegistry to improve separation of concerns*


## State Variables
### members

Mapping of member addresses to their member data


```solidity
mapping(address => Member) internal members;
```


### committeesCandidates

Mapping of stream denomination and role to list of candidate addresses


```solidity
mapping(StreamDenomination denomination => mapping(Role role => address[] membersAddress)) internal
    committeesCandidates;
```


### streamManager

Stream manager contract for managing streams and packets


```solidity
IStreamManager public streamManager;
```


### committeeRegistry

Committee registry contract for committee operations


```solidity
address public committeeRegistry;
```


## Functions
### initialize

Initializes the MemberRegistry contract

*Sets up the initial owner for the contract*


```solidity
function initialize(address _initialOwner) public virtual initializer;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_initialOwner`|`address`|The initial owner of the contract|


### applyToStream

Internal function to handle member application to stream

*Called by CommitteeRegistry to handle member registration and candidacy*

*Validates funding UTXO and public keys before processing application*


```solidity
function applyToStream(
    address _memberAddress,
    StreamDenomination _stream,
    Role _role,
    MemberRegistrationKeys calldata _publicKeys,
    UTXO calldata _fundingUTXO
) external payable;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_memberAddress`|`address`|The address of the member applying|
|`_stream`|`StreamDenomination`|The stream denomination to apply for|
|`_role`|`Role`|The role requested in the committee|
|`_publicKeys`|`MemberRegistrationKeys`|Member registration public keys|
|`_fundingUTXO`|`UTXO`|The Bitcoin UTXO that will be used for the member funding|


### unsubscribeFromStream

Internal function to handle member unsubscription from stream

*Called by CommitteeRegistry after pending committee checks*

*Removes member from candidate list and handles balance adjustments*


```solidity
function unsubscribeFromStream(address _memberAddress, StreamDenomination _denomination) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_memberAddress`|`address`|The address of the member unsubscribing|
|`_denomination`|`StreamDenomination`|The stream denomination to unsubscribe from|


### withdrawAvailableBalance

Withdraws available balance to the caller's address

*Can only withdraw balance that is not pre-staked or staked*

*Calculates available balance as total balance minus pre-staked and staked amounts*


```solidity
function withdrawAvailableBalance() external;
```

### selectCommitteeMembers

Internal function to select committee members

*Called by CommitteeRegistry to select members for a new committee*

*Implements selection algorithm based on member availability and staking requirements*


```solidity
function selectCommitteeMembers(uint64 _streamId, uint64 _packetNumber)
    external
    returns (CommitteeMember[] memory, PendingCommitteeStatus);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_streamId`|`uint64`|The stream ID to select committee for|
|`_packetNumber`|`uint64`|The packet number for committee selection|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`CommitteeMember[]`|Array of selected committee members|
|`<none>`|`PendingCommitteeStatus`|Status indicating success or failure reason|


### getMemberTakePubKey

Gets the member's take public key for a given address

*Used for operator take operations during pegout processes*


```solidity
function getMemberTakePubKey(address _memberAddress) external view returns (bytes32);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_memberAddress`|`address`|The member address to get the take public key for|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|The member's take public key|


### getCandidatesCount

Gets the count of candidates for a specific stream denomination and role

*Used to check committee formation feasibility*


```solidity
function getCandidatesCount(StreamDenomination _denomination, Role _role) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_denomination`|`StreamDenomination`|The stream denomination|
|`_role`|`Role`|The role to check candidates for|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Number of candidates for the specified stream and role|


### getMemberData

Gets member data for a specific address

*Returns complete member information including keys and balance data*


```solidity
function getMemberData(address _memberAddress) external view returns (Member memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_memberAddress`|`address`|The member address to get data for|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`Member`|The member data struct|


### setStreamManager

Sets the stream manager contract address

*Only callable by contract owner*

*Updates the stream manager reference for stream operations*


```solidity
function setStreamManager(address _streamManager) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_streamManager`|`address`|The new stream manager contract address|


### setCommitteeRegistry

Sets the committee registry contract address

*Only callable by contract owner*

*Updates the committee registry reference for coordination*


```solidity
function setCommitteeRegistry(address _committeeRegistry) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_committeeRegistry`|`address`|The new committee registry contract address|


## Events
### MemberRegistered

Emitted when a new member is registered in the system


```solidity
event MemberRegistered(address indexed memberAddress, MemberRegistrationKeys publicKeys);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`memberAddress`|`address`|The address of the registered member|
|`publicKeys`|`MemberRegistrationKeys`|The public keys provided during registration|

### MemberAppliedToStream

Emitted when a member applies to a stream with a specific role


```solidity
event MemberAppliedToStream(
    address indexed memberAddress, StreamDenomination indexed stream, Role indexed role, UTXO fundingUTXO
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`memberAddress`|`address`|The address of the applying member|
|`stream`|`StreamDenomination`|The stream denomination applied to|
|`role`|`Role`|The requested role in the committee|
|`fundingUTXO`|`UTXO`|The Bitcoin UTXO for member funding|

### MemberUnsubscribedFromStream

Emitted when a member unsubscribes from a stream


```solidity
event MemberUnsubscribedFromStream(address indexed memberAddress, StreamDenomination indexed stream);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`memberAddress`|`address`|The address of the member unsubscribing|
|`stream`|`StreamDenomination`|The stream denomination unsubscribed from|

### BalanceWithdrawn

Emitted when a member withdraws their available balance


```solidity
event BalanceWithdrawn(address indexed memberAddress, uint256 amount);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`memberAddress`|`address`|The address of the member withdrawing|
|`amount`|`uint256`|The amount withdrawn in wei|

## Errors
### InvalidMemberAddress

Thrown when an invalid member address is provided


```solidity
error InvalidMemberAddress(address memberAddress);
```

### MemberAlreadyRegistered

Thrown when attempting to register an already registered member


```solidity
error MemberAlreadyRegistered(address memberAddress);
```

### MemberNotRegistered

Thrown when attempting to operate on a non-registered member


```solidity
error MemberNotRegistered(address memberAddress);
```

### MemberAlreadyAppliedToStream

Thrown when a member attempts to apply to a stream they're already applied to


```solidity
error MemberAlreadyAppliedToStream(address memberAddress, StreamDenomination stream);
```

### MemberNotAppliedToStream

Thrown when attempting to operate on a member not applied to a stream


```solidity
error MemberNotAppliedToStream(address memberAddress, StreamDenomination stream);
```

### InsufficientBalance

Thrown when a member has insufficient balance for an operation


```solidity
error InsufficientBalance(address memberAddress, uint256 required, uint256 available);
```

### ZeroUTXOTxid

Thrown when a UTXO has a zero transaction ID


```solidity
error ZeroUTXOTxid(UTXO utxo);
```

### ZeroUTXOAmount

Thrown when a UTXO has zero amount


```solidity
error ZeroUTXOAmount(UTXO utxo);
```

### InvalidPublicKeyLength

Thrown when a public key has invalid length


```solidity
error InvalidPublicKeyLength(uint256 actual, uint256 expected);
```

### OnlyCommitteeRegistry

Thrown when a function is called by an address other than the committee registry


```solidity
error OnlyCommitteeRegistry(address caller);
```