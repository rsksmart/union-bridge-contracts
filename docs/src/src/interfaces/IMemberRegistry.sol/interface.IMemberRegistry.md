# IMemberRegistry
[Git Source](https://github.com/temp-rsk/bitvmx-union-bridge-contracts/blob/main/src/interfaces/IMemberRegistry.sol)

**Inherits:**
None

Interface for managing committee member registration, applications, and balance tracking

*Handles member lifecycle operations including registration, candidacy, and balance management*


## Functions
### applyToStream

Internal function to handle member application to stream

*Called by CommitteeRegistry to handle member registration and candidacy*


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


```solidity
function withdrawAvailableBalance() external;
```

### selectCommitteeMembers

Internal function to select committee members

*Called by CommitteeRegistry to select members for a new committee*


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

*Used for operator take operations*


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

```solidity
error InvalidMemberAddress(address memberAddress);
```

### MemberAlreadyRegistered

```solidity
error MemberAlreadyRegistered(address memberAddress);
```

### MemberNotRegistered

```solidity
error MemberNotRegistered(address memberAddress);
```

### MemberAlreadyAppliedToStream

```solidity
error MemberAlreadyAppliedToStream(address memberAddress, StreamDenomination stream);
```

### MemberNotAppliedToStream

```solidity
error MemberNotAppliedToStream(address memberAddress, StreamDenomination stream);
```

### InsufficientBalance

```solidity
error InsufficientBalance(address memberAddress, uint256 required, uint256 available);
```

### ZeroUTXOTxid

```solidity
error ZeroUTXOTxid(UTXO utxo);
```

### ZeroUTXOAmount

```solidity
error ZeroUTXOAmount(UTXO utxo);
```

### InvalidPublicKeyLength

```solidity
error InvalidPublicKeyLength(uint256 actual, uint256 expected);
```

### OnlyCommitteeRegistry

```solidity
error OnlyCommitteeRegistry(address caller);
```
