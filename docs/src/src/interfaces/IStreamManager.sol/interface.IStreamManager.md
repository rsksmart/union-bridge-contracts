# IStreamManager
[Git Source](https://github.com/FairgateLabs/bitvmx-union-bridge-contracts/blob/3db9056f26f2b3b61c05819d9eb725e59c32f233/src/interfaces/IStreamManager.sol)

**Inherits:**
[IAccessControl](/src/interfaces/IAccessControl.sol/interface.IAccessControl.md)

Interface for managing streams, packets, and slots in the union bridge

*This interface provides functions for organizing and tracking funds through the hierarchical structure*

*Manages the lifecycle of funds from peg-in to peg-out through streams, packets, and slots*


## Functions
### createNewPacket

Creates a new packet in a specific stream with committee assignment

*Only callable by the CommitteeRegistry smart contract*


```solidity
function createNewPacket(uint64 _streamId, uint128 _committeeId, bytes calldata _committeePubKey) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_streamId`|`uint64`|The index of the stream to add the packet to|
|`_committeeId`|`uint128`|The ID of the committee responsible for this packet|
|`_committeePubKey`|`bytes`|The public key of the selected committee for the packet (33 bytes)|


### getStream

Retrieves stream information for a given denomination

*Looks up the stream that handles the specified Bitcoin amount*


```solidity
function getStream(uint64 _denomination) external view returns (Stream calldata);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_denomination`|`uint64`|The value in satoshis used to identify the stream|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`Stream`|Stream The complete stream information|


### getStreamById

Retrieves stream information for a given stream ID

*Direct lookup by stream index*


```solidity
function getStreamById(uint64 _streamId) external view returns (Stream calldata);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_streamId`|`uint64`|The index of the stream to retrieve|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`Stream`|Stream The complete stream information|


### getStreamsLength

Gets the total number of streams in the system


```solidity
function getStreamsLength() external view returns (uint64);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint64`|uint64 The number of streams|


### getPacketsLength

Gets the number of packets in a specific stream


```solidity
function getPacketsLength(uint64 _streamId) external view returns (uint64);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_streamId`|`uint64`|The index of the stream|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint64`|uint64 The number of packets in the stream|


### getPacket

Retrieves packet information for a specific packet in a stream


```solidity
function getPacket(uint64 _streamId, uint64 _packetNumber) external view returns (Packet memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_streamId`|`uint64`|The index of the stream|
|`_packetNumber`|`uint64`|The index of the packet within the stream|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`Packet`|Packet The complete packet information|


### lockSlot

Locks the first filled slot in a stream for peg-out processing

*Returns the slot information and packet number for the locked slot*


```solidity
function lockSlot(uint64 _streamId) external returns (Slot memory, uint64 packetNumber);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_streamId`|`uint64`|The index of the stream|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`Slot`|slot The slot information for the locked slot|
|`packetNumber`|`uint64`|The packet number containing the locked slot|


### getSlot

Retrieves slot information for a specific slot in a packet


```solidity
function getSlot(uint64 _streamId, uint64 _packetNumber, uint64 _slotNumber) external view returns (Slot memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_streamId`|`uint64`|The index of the stream|
|`_packetNumber`|`uint64`|The index of the packet within the stream|
|`_slotNumber`|`uint64`|The index of the slot within the packet|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`Slot`|Slot The complete slot information|


### reserveSlot

Reserves a slot for a peg-in request

*Creates a new slot with RESERVED state during request peg-in*


```solidity
function reserveSlot(uint64 _streamId, uint64 _packetNumber) external returns (uint64);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_streamId`|`uint64`|The index of the stream|
|`_packetNumber`|`uint64`|The index of the packet within the stream|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint64`|uint64 The slot ID of the reserved slot|


### fillSlot

Fills a slot with accept peg-in transaction information

*Updates the slot state from RESERVED to FILLED and stores transaction details*


```solidity
function fillSlot(
    StreamPosition memory _stream,
    uint64 _acceptPeginAmount,
    bytes32 _acceptPeginTx,
    bytes memory _scriptPubKey
) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_stream`|`StreamPosition`|The struct containing the stream, packet, and slot information|
|`_acceptPeginAmount`|`uint64`|The amount of the accept peg-in transaction in satoshis|
|`_acceptPeginTx`|`bytes32`|The transaction ID of the accept peg-in transaction|
|`_scriptPubKey`|`bytes`|The scriptPubKey of the accept peg-in transaction|


### blockSlot

Blocks a reserved slot due to timeout or refund proof

*Updates the slot state from RESERVED to BLOCKED*


```solidity
function blockSlot(uint64 _streamId, uint64 _packetNumber, uint64 _slotId) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_streamId`|`uint64`|The index of the stream|
|`_packetNumber`|`uint64`|The index of the packet within the stream|
|`_slotId`|`uint64`|The ID of the slot to block|


### getCommitteeId

Retrieves the committee ID for a specific packet


```solidity
function getCommitteeId(uint64 _streamId, uint64 _packetNumber) external view returns (uint128);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_streamId`|`uint64`|The index of the stream|
|`_packetNumber`|`uint64`|The index of the packet within the stream|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint128`|uint256 The committee ID responsible for this packet|


### getCommitteePubKey

Retrieves the committee public key for a specific packet


```solidity
function getCommitteePubKey(uint64 _streamId, uint64 _packetNumber) external view returns (bytes memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_streamId`|`uint64`|The index of the stream|
|`_packetNumber`|`uint64`|The index of the packet within the stream|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes`|bytes The committee public key for this packet (33 bytes)|


### completeSlot

Marks a slot as paid and updates its state

*Updates the slot state to COMPLETED and stores the peg-out transaction ID*


```solidity
function completeSlot(
    uint64 _streamId,
    uint64 _packetNumber,
    uint64 _slotId,
    bytes32 _acceptPeginTxHash,
    bytes32 _userTakeTx
) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_streamId`|`uint64`|The index of the stream|
|`_packetNumber`|`uint64`|The index of the packet within the stream|
|`_slotId`|`uint64`|The index of the slot within the packet|
|`_acceptPeginTxHash`|`bytes32`|The expected accept peg-in transaction hash for validation|
|`_userTakeTx`|`bytes32`|The transaction ID of the normal peg-out transaction|


### advanceSlot

Marks a slot as advanced by the operator to the user

*Updates the slot state to ADVANCED and stores the operator's peg-out transaction*


```solidity
function advanceSlot(uint64 _streamId, uint64 _packetNumber, uint64 _slotId) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_streamId`|`uint64`|The index of the stream|
|`_packetNumber`|`uint64`|The index of the packet within the stream|
|`_slotId`|`uint64`|The index of the slot within the packet|


### setPeginConfirmations

Sets the number of confirmations required for peg-in transactions

*Only callable by the contract owner*


```solidity
function setPeginConfirmations(uint64 _streamId, uint8 _confirmations) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_streamId`|`uint64`|The index of the stream|
|`_confirmations`|`uint8`|The number of confirmations required for peg-in transactions|


### setPegoutConfirmations

Sets the number of confirmations required for peg-out transactions

*Only callable by the contract owner*


```solidity
function setPegoutConfirmations(uint64 _streamId, uint8 _confirmations) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_streamId`|`uint64`|The index of the stream|
|`_confirmations`|`uint8`|The number of confirmations required for peg-out transactions|


### getAvailablePeginCommitteeId

Gets the committee ID for the current packet in a stream


```solidity
function getAvailablePeginCommitteeId(uint64 _streamId) external view returns (uint128);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_streamId`|`uint64`|The index of the stream|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint128`|uint256 The committee ID for the current packet (returns 0 if no current packet)|


### getMinimumDeposit

Gets the minimum deposit required for a specific denomination and role


```solidity
function getMinimumDeposit(StreamDenomination _denomination, Role _role) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_denomination`|`StreamDenomination`|The denomination of the stream|
|`_role`|`Role`|The role of the user (e.g., OPERATOR, WATCHTOWER)|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|uint256 The minimum deposit required in wei|


### setSecurityBondPercentage

Sets the security bond percentage for a specific role

*The percentage must be between 0 and 10000, where 10000 represents 100%*

*Only callable by the contract owner*

*Emits a SecurityBondPercentageUpdated event on success*


```solidity
function setSecurityBondPercentage(Role _role, uint16 _percentage) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_role`|`Role`|The role for which to set the security bond percentage|
|`_percentage`|`uint16`|The new security bond percentage to set|


### setMinimumSecurityDeposit

Sets the minimum security deposit required for the system

*Only callable by the contract owner*

*Emits a MinimumSecurityDepositUpdated event on success*


```solidity
function setMinimumSecurityDeposit(uint256 _cost) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_cost`|`uint256`|The new minimum security deposit in wei|


### setDisablementPaymentsPerChallenge

Sets the disablement payments per challenge

*Only callable by the contract owner*

*Emits a DisablementPaymentsPerChallengeUpdated event on success*


```solidity
function setDisablementPaymentsPerChallenge(uint256 _cost) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_cost`|`uint256`|The new disablement payments per challenge in wei|


## Events
### StreamCreated
Event emitted when a new stream is created


```solidity
event StreamCreated(uint64 streamId, uint64 denomination);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`streamId`|`uint64`|The ID of the newly created stream|
|`denomination`|`uint64`|The denomination of the stream in satoshis|

### PacketCreated
Event emitted when a new packet is created


```solidity
event PacketCreated(uint64 streamId, uint64 packetNumber);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`streamId`|`uint64`|The ID of the stream containing the packet|
|`packetNumber`|`uint64`|The number of the newly created packet|

### SlotReserved
Event emitted when a new slot is created


```solidity
event SlotReserved(uint64 streamId, uint64 packetNumber, uint64 slotId);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`streamId`|`uint64`|The ID of the stream containing the slot|
|`packetNumber`|`uint64`|The number of the packet containing the slot|
|`slotId`|`uint64`|The ID of the newly created slot|

### SlotFilled
Event emitted when a slot is filled with accept peg-in transaction details


```solidity
event SlotFilled(uint64 streamId, uint64 packetNumber, uint64 slotId, bytes32 acceptPeginTx, uint64 acceptPeginAmount);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`streamId`|`uint64`|The ID of the stream containing the slot|
|`packetNumber`|`uint64`|The number of the packet containing the slot|
|`slotId`|`uint64`|The ID of the slot that was filled|
|`acceptPeginTx`|`bytes32`|The hash of the accept peg-in transaction|
|`acceptPeginAmount`|`uint64`|The amount of the accept peg-in transaction|

### SecurityBondPercentageUpdated
Event emitted when Security Bond Percentage is updated

*The percentage is represented as a value between 0 and 10000,
where 10000 represents 100%*


```solidity
event SecurityBondPercentageUpdated(Role role, uint16 percentage);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`role`|`Role`|The role for which the security bond percentage was updated|
|`percentage`|`uint16`|The new security bond percentage for the role|

### MinimumSecurityDepositUpdated
Event emitted when the minimum security deposit is updated


```solidity
event MinimumSecurityDepositUpdated(uint256 cost);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`cost`|`uint256`|The new minimum security deposit in wei|

### DisablementPaymentsPerChallengeUpdated
Event emitted when disablement payments per challenge are updated


```solidity
event DisablementPaymentsPerChallengeUpdated(uint256 newCost);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newCost`|`uint256`|The new disablement payments per challenge in wei|

## Errors
### StreamNotFoundByDenomination
Thrown when a stream is not found for the given denomination


```solidity
error StreamNotFoundByDenomination(uint256 denomination);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`denomination`|`uint256`|The denomination that was not found|

### StreamNotFoundById
Thrown when a stream is not found for the given stream ID


```solidity
error StreamNotFoundById(uint256 streamId);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`streamId`|`uint256`|The stream ID that was not found|

### PacketOutOfBound
Thrown when a packet number is out of bounds


```solidity
error PacketOutOfBound(uint256 packetNumber);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`packetNumber`|`uint256`|The packet number that is out of bounds|

### NoEmptySlot
Thrown when there are no empty slots available in a packet


```solidity
error NoEmptySlot(uint256 streamId, uint256 packetNumber);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`streamId`|`uint256`|The stream ID|
|`packetNumber`|`uint256`|The packet number|

### tooManyDenominations
Thrown when there are too many denominations


```solidity
error tooManyDenominations(uint256 maxDenominationsSize);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`maxDenominationsSize`|`uint256`|The maximum number of denominations allowed|

### NoFilledSlot
Thrown when there are no filled slots available for a given stream


```solidity
error NoFilledSlot(uint256 streamId);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`streamId`|`uint256`|The stream ID|

### _InconsistentSlotState
Thrown when a slot is in an unexpected state during lockSlot


```solidity
error _InconsistentSlotState(uint256 streamId, uint256 packetNumber, uint256 slotId, SlotState currentState);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`streamId`|`uint256`|The stream ID|
|`packetNumber`|`uint256`|The packet number|
|`slotId`|`uint256`|The slot ID|
|`currentState`|`SlotState`|The unexpected state|

### NoPacketAvailable
Thrown when no packets are available for a given stream


```solidity
error NoPacketAvailable(uint256 streamId);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`streamId`|`uint256`|The stream ID|

### _InconsistentSlotsPerPacket
Thrown when there are inconsistent slots per packet


```solidity
error _InconsistentSlotsPerPacket(uint256 streamId, uint256 packetNumber, uint256 slotsPerPacket);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`streamId`|`uint256`|The stream ID|
|`packetNumber`|`uint256`|The packet number|
|`slotsPerPacket`|`uint256`|The number of slots per packet|

### InvalidPeginPacketNumber
Thrown when the peg-in packet number is invalid


```solidity
error InvalidPeginPacketNumber(uint256 streamId, uint256 packetNumber);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`streamId`|`uint256`|The stream ID|
|`packetNumber`|`uint256`|The invalid packet number|

### NonExistentSlot
Thrown when a slot does not exist


```solidity
error NonExistentSlot(uint256 streamId, uint256 packetNumber, uint256 slotId);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`streamId`|`uint256`|The stream ID|
|`packetNumber`|`uint256`|The packet number|
|`slotId`|`uint256`|The slot ID|

### StreamAlreadyInitialized
Thrown when a stream is already initialized


```solidity
error StreamAlreadyInitialized(uint256 streamId);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`streamId`|`uint256`|The stream ID that is already initialized|

### InvalidPeginConfirmations
Thrown when peg-in confirmations are invalid


```solidity
error InvalidPeginConfirmations(uint8 confirmations);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`confirmations`|`uint8`|The invalid number of confirmations|

### InvalidPegoutConfirmations
Thrown when peg-out confirmations are invalid


```solidity
error InvalidPegoutConfirmations(uint8 confirmations);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`confirmations`|`uint8`|The invalid number of confirmations|

### InvalidSlotState
Thrown when the slot state doesn't match the expected state


```solidity
error InvalidSlotState(SlotState actual, SlotState expected);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`actual`|`SlotState`|The actual slot state|
|`expected`|`SlotState`|The expected slot state|

### InvalidAcceptPeginTxHash
Thrown when the accept peg-in transaction hash doesn't match


```solidity
error InvalidAcceptPeginTxHash(bytes32 expected, bytes32 actual);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`expected`|`bytes32`|The expected transaction hash|
|`actual`|`bytes32`|The actual transaction hash|

### InvalidZeroAddress
Thrown when an address is zero


```solidity
error InvalidZeroAddress();
```

### InvalidPercentage
Thrown when a percentage value is invalid

*The percentage must be between 0 and 10000, where 10000 represents 100%*


```solidity
error InvalidPercentage(uint16 percentage);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`percentage`|`uint16`|The invalid percentage value|

### InvalidRole
Thrown when a role is invalid


```solidity
error InvalidRole(Role role);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`role`|`Role`|The invalid role|

### InvalidZeroValue
Thrown when a value is zero when it shouldn't be


```solidity
error InvalidZeroValue();
```

### SlotNotReserved
Thrown when trying to fill a slot that's not reserved


```solidity
error SlotNotReserved(uint256 streamId, uint256 packetNumber, uint256 slotId, SlotState currentState);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`streamId`|`uint256`|The stream ID|
|`packetNumber`|`uint256`|The packet number|
|`slotId`|`uint256`|The slot ID|
|`currentState`|`SlotState`|The current state of the slot|

### SlotNotBlockable
Thrown when trying to block a slot that's not reserved


```solidity
error SlotNotBlockable(uint256 streamId, uint256 packetNumber, uint256 slotId, SlotState currentState);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`streamId`|`uint256`|The stream ID|
|`packetNumber`|`uint256`|The packet number|
|`slotId`|`uint256`|The slot ID|
|`currentState`|`SlotState`|The current state of the slot|

