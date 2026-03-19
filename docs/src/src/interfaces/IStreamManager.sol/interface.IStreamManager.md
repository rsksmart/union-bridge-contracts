# IStreamManager
[Git Source](https://github.com/temp-rsk/bitvmx-union-bridge-contracts/blob/ee0115174aa9f16d975ad140f940d23fb1883b23/src/interfaces/IStreamManager.sol)

Interface for managing streams, packets, and slots in the union bridge

*This interface provides functions for organizing and tracking funds through the hierarchical structure*

*Manages the lifecycle of funds from peg-in to peg-out through streams, packets, and slots*


## Functions
### createNewPacket

Creates a new packet for a stream

*Can only be called by the CommitteeRegistry when a new committee is formed*


```solidity
function createNewPacket(
    uint64 _streamId,
    uint128 _committeeId,
    bytes memory _committeePubKey,
    CompactPubKey[] memory _disputeKeys
) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_streamId`|`uint64`|The ID of the stream to create a packet for|
|`_committeeId`|`uint128`|The ID of the committee that will process this packet|
|`_committeePubKey`|`bytes`|The aggregated key of the committee for Bitcoin operations|
|`_disputeKeys`|`CompactPubKey[]`|The dispute keys for the committee members|


### getStream

Gets a stream by its denomination


```solidity
function getStream(uint64 _denomination) external view returns (Stream calldata);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_denomination`|`uint64`|The Bitcoin denomination in satoshis|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`Stream`|The stream data for the given denomination|


### getStreamById

Gets a stream by its ID


```solidity
function getStreamById(uint64 _streamId) external view returns (Stream calldata);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_streamId`|`uint64`|The ID of the stream|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`Stream`|The stream data for the given ID|


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
|`_streamId`|`uint64`|The ID of the stream|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint64`|uint64 The number of packets in the stream|


### getPacket

Gets a specific packet from a stream


```solidity
function getPacket(uint64 _streamId, uint64 _packetNumber) external view returns (Packet memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_streamId`|`uint64`|The ID of the stream|
|`_packetNumber`|`uint64`|The packet number to retrieve|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`Packet`|The packet data|


### getNextPegoutSlotLocation

Gets the slot location that next pegout would have

*Throws when there are no more filled slots - cant do a pegout*


```solidity
function getNextPegoutSlotLocation(uint64 _streamId) external view returns (SlotLocation memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_streamId`|`uint64`|The ID of the stream|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`SlotLocation`|The slot location data|


### hasPegoutInProcess

Returns whether there is a pegout in process associated to a stream


```solidity
function hasPegoutInProcess(uint64 _streamId) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_streamId`|`uint64`|The ID of the stream|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if there is a pegout in process, false if not|


### lockSlot

Returns the first filled slot, locks it, and updates the peg-out pointers

Reverts if a pegout is already in progress for the same stream

*Can only be called by the PegManager*


```solidity
function lockSlot(uint64 _streamId) external returns (Slot memory, uint64 packetNumber);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_streamId`|`uint64`|The ID of the stream|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`Slot`|slot The locked slot data|
|`packetNumber`|`uint64`|The packet number containing the slot|


### getSlot

Gets a specific slot from a stream and packet


```solidity
function getSlot(uint64 _streamId, uint64 _packetNumber, uint64 _slotNumber) external view returns (Slot memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_streamId`|`uint64`|The ID of the stream|
|`_packetNumber`|`uint64`|The packet number|
|`_slotNumber`|`uint64`|The slot number within the packet|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`Slot`|The slot data|


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
|`_scriptPubKey`|`bytes`|The scriptPubKey of the accept peg-in taptree output|


### blockSlot

Blocks a reserved slot due to timeout or refund proof

*Updates the slot state from RESERVED to BLOCKED and sets peg status to BLOCKED*

*Close the packet if blocked slot is the last one*


```solidity
function blockSlot(bytes32 _acceptPeginTxid) external returns (bool packetClosed);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_acceptPeginTxid`|`bytes32`|The accept peg-in transaction ID to block|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`packetClosed`|`bool`|Whether the packet was closed or not|


### getCommitteeId

Gets the committee ID for a specific packet


```solidity
function getCommitteeId(uint64 _streamId, uint64 _packetNumber) external view returns (uint128);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_streamId`|`uint64`|The ID of the stream|
|`_packetNumber`|`uint64`|The packet number|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint128`|uint128 The committee ID for the packet|


### getEnablerScriptPubKey

Retrieves the enabler script public key for a specific packet


```solidity
function getEnablerScriptPubKey(uint64 _streamId, uint64 _packetNumber) external view returns (bytes memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_streamId`|`uint64`|The ID of the stream|
|`_packetNumber`|`uint64`|The index of the packet within the stream|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes`|bytes The enabler script public key for this packet|


### completeSlot

Marks a slot as completed and stores the UserTake transaction id

*Can only be called by the PegManager*

*Close the packet if completed slot is the last one*


```solidity
function completeSlot(bytes32 _acceptPeginTxid, bytes32 _userTakeTx) external returns (bool packetClosed);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_acceptPeginTxid`|`bytes32`|The hash of the accept peg-in transaction|
|`_userTakeTx`|`bytes32`|The hash of the UserTake transaction|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`packetClosed`|`bool`|Whether the packet was closed or not|


### advanceSlot

Marks a slot as advanced by the operator to the user

*Updates the slot state to ADVANCED and stores the operator's peg-out transaction*


```solidity
function advanceSlot(bytes32 _acceptPeginTxid) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_acceptPeginTxid`|`bytes32`|The accept peg-in transaction ID|


### setPeginConfirmations

Sets the number of confirmations required for peg-in transactions

*Only callable by the contract owner*


```solidity
function setPeginConfirmations(uint64 _streamId, uint8 _confirmations) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_streamId`|`uint64`|The ID of the stream|
|`_confirmations`|`uint8`|The number of confirmations required for peg-in transactions|


### setRejectPeginConfirmations

Sets the number of confirmations required for reject pegin and user reimbursement transactions

*Only callable by the contract owner*


```solidity
function setRejectPeginConfirmations(uint64 _streamId, uint8 _confirmations) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_streamId`|`uint64`|The ID of the stream|
|`_confirmations`|`uint8`|The number of confirmations required for reject pegin and user reimbursement|


### setPegoutConfirmations

Sets the number of confirmations required for peg-out transactions

*Only callable by the contract owner*


```solidity
function setPegoutConfirmations(uint64 _streamId, uint8 _confirmations) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_streamId`|`uint64`|The ID of the stream|
|`_confirmations`|`uint8`|The number of confirmations required for peg-out transactions|


### getAvailablePeginCommitteeId

Gets the committee ID for the available pegin packet in a stream


```solidity
function getAvailablePeginCommitteeId(uint64 _streamId) external view returns (uint128);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_streamId`|`uint64`|The ID of the stream|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint128`|The committee ID, or 0 if no current packet|


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


### setTimelockSettings

Sets the timelock settings for a stream

*Can only be called by the owner*


```solidity
function setTimelockSettings(uint64 _streamId, TimelockSettings memory _timelockSettings) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_streamId`|`uint64`|The ID of the stream|
|`_timelockSettings`|`TimelockSettings`|The timelock settings to set|


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

Sets the disablement payments cost per challenge, this is used to calculate the minimum deposit for a role

*Can only be called by the owner*

*Emits a DisablementPaymentsPerChallengeUpdated event on success*


```solidity
function setDisablementPaymentsPerChallenge(uint256 _cost) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_cost`|`uint256`|The new disablement payments per challenge in wei|


### setStreamPosition

Stores the stream position for a given accept peg-in transaction ID

*Only callable by the PegManager contract*


```solidity
function setStreamPosition(bytes32 _acceptPeginTxid, StreamPosition memory _position) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_acceptPeginTxid`|`bytes32`|The accept peg-in transaction ID|
|`_position`|`StreamPosition`|The stream position to store|


### getStreamPosition

Retrieves the stream position for a given accept peg-in transaction ID


```solidity
function getStreamPosition(bytes32 _acceptPeginTxid) external view returns (StreamPosition memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_acceptPeginTxid`|`bytes32`|The accept peg-in transaction ID|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`StreamPosition`|The stream position associated with the transaction ID|


### validatePeginStatus

Validates peg-in status and returns the stream position

*Reverts with PeginNotRequested if the peg-in was not requested*

*Reverts with InvalidPegStatus if the current status does not match the expected status*


```solidity
function validatePeginStatus(bytes32 _acceptPeginTxid, PegStatus _expectedStatus)
    external
    view
    returns (StreamPosition memory streamPosition);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_acceptPeginTxid`|`bytes32`|The accept peg-in transaction ID|
|`_expectedStatus`|`PegStatus`|The expected peg status for the operation|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`streamPosition`|`StreamPosition`|The stream position if validation passes|


### validatePegoutStatus

Validates peg-out status and returns stream position, committee ID, and peg-out confirmations

*Reverts with PeginNotRequested if the peg-in was not requested*

*Reverts with InvalidPegStatus if the current status does not match the expected status*


```solidity
function validatePegoutStatus(bytes32 _acceptPeginTxid, PegStatus _expectedStatus)
    external
    view
    returns (StreamPosition memory streamPosition, uint128 committeeId, uint8 pegoutConfirmations);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_acceptPeginTxid`|`bytes32`|The accept peg-in transaction ID|
|`_expectedStatus`|`PegStatus`|The expected peg status for the operation|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`streamPosition`|`StreamPosition`|The stream position if validation passes|
|`committeeId`|`uint128`|The committee ID for the packet|
|`pegoutConfirmations`|`uint8`|The number of confirmations required for peg-out transactions|


### getPacketSlotsLength

Gets the length of the slots in a packet


```solidity
function getPacketSlotsLength(uint64 _streamId, uint64 _packetNumber) external view returns (uint64);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_streamId`|`uint64`|The ID of the stream|
|`_packetNumber`|`uint64`|The packet number|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint64`|The length of the slots in the packet|


### setPegStatus

Updates only the peg status of an existing stream position

*Only callable by the PegManager contract*


```solidity
function setPegStatus(bytes32 _acceptPeginTxid, PegStatus _newStatus) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_acceptPeginTxid`|`bytes32`|The accept peg-in transaction ID|
|`_newStatus`|`PegStatus`|The new peg status to set|


### getFilledSlotsCount

Gets the number of remaining filled slots available for peg-out in the given stream


```solidity
function getFilledSlotsCount(uint64 _streamId) external view returns (uint64);
```

### restartStreamPointers_TESTNET


```solidity
function restartStreamPointers_TESTNET(uint64 _streamId) external;
```

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

### PacketClosed
Event emitted when a packet is closed in the stream

*Indicates that all slots in the packet have been processed and pegged out*

*This event is used to track the lifecycle of packets in the stream*


```solidity
event PacketClosed(uint64 indexed streamId, uint64 indexed packetNumber);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`streamId`|`uint64`|The ID of the stream where the packet was closed|
|`packetNumber`|`uint64`|The number of the packet that was closed|

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

### StreamPositionSet
Event emitted when a stream position is set


```solidity
event StreamPositionSet(bytes32 indexed acceptPeginTxid, StreamPosition position);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`acceptPeginTxid`|`bytes32`|The accept peg-in transaction ID|
|`position`|`StreamPosition`|The stream position that was set|

### PegStatusUpdated
Event emitted when a peg status is updated


```solidity
event PegStatusUpdated(bytes32 indexed acceptPeginTxid, PegStatus newStatus);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`acceptPeginTxid`|`bytes32`|The accept peg-in transaction ID|
|`newStatus`|`PegStatus`|The new peg status|

### PeginConfirmationsUpdated
Event emitted when the number of confirmations required for peg-in transactions is updated


```solidity
event PeginConfirmationsUpdated(uint64 _streamId, uint8 _confirmations);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_streamId`|`uint64`|The ID of the stream|
|`_confirmations`|`uint8`|The number of confirmations required|

### RejectPeginConfirmationsUpdated
Event emitted when the number of confirmations required for reject pegin and user reimbursement is updated


```solidity
event RejectPeginConfirmationsUpdated(uint64 _streamId, uint8 _confirmations);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_streamId`|`uint64`|The ID of the stream|
|`_confirmations`|`uint8`|The number of confirmations required|

### PegoutConfirmationsUpdated
Event emitted when the number of confirmations required for peg-out transactions is updated


```solidity
event PegoutConfirmationsUpdated(uint64 _streamId, uint8 _confirmations);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_streamId`|`uint64`|The ID of the stream|
|`_confirmations`|`uint8`|The number of confirmations required|

### TimelockSettingsUpdated
Event emitted when the timelock settings are updated


```solidity
event TimelockSettingsUpdated(uint64 _streamId, TimelockSettings _timelockSettings);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_streamId`|`uint64`|The ID of the stream|
|`_timelockSettings`|`TimelockSettings`|The timelock settings that were updated|

### StreamPointersRestarted

```solidity
event StreamPointersRestarted(uint64 streamId);
```

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

### PegoutInProcess
Thrown when there is already a pegout in process for a given stream


```solidity
error PegoutInProcess(uint256 streamId);
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

### StreamsAlreadyInitialized
Thrown when streams are already initialized


```solidity
error StreamsAlreadyInitialized();
```

### InvalidPeginConfirmations
Thrown when peg-in confirmations are invalid


```solidity
error InvalidPeginConfirmations(uint8 confirmations);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`confirmations`|`uint8`|The invalid number of confirmations|

### InvalidRejectPeginConfirmations
Thrown when reject pegin confirmations are invalid


```solidity
error InvalidRejectPeginConfirmations(uint8 confirmations);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`confirmations`|`uint8`|The invalid number of confirmations|

### RejectPeginConfirmationsExceedsPegin
Thrown when reject pegin confirmations exceed pegin confirmations


```solidity
error RejectPeginConfirmationsExceedsPegin(uint8 rejectPeginConfirmations, uint8 peginConfirmations);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`rejectPeginConfirmations`|`uint8`|The requested reject pegin confirmations|
|`peginConfirmations`|`uint8`|The stream's pegin confirmations (reject must be <= this)|

### PeginConfirmationsLowerThanRejectPegin
Thrown when pegin confirmations are set lower than reject pegin confirmations


```solidity
error PeginConfirmationsLowerThanRejectPegin(uint8 peginConfirmations, uint8 rejectPeginConfirmations);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`peginConfirmations`|`uint8`|The requested pegin confirmations|
|`rejectPeginConfirmations`|`uint8`|The stream's reject pegin confirmations (pegin must be >= this)|

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

### InvalidZeroAddress
Thrown when an address is zero address


```solidity
error InvalidZeroAddress();
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

### InvalidTimelockSettings
Thrown when the timelock settings are invalid


```solidity
error InvalidTimelockSettings(TimelockSettings timelockSettings);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`timelockSettings`|`TimelockSettings`|The invalid timelock settings|

### InvalidStreamSettings
Thrown when the stream settings confirmations are invalid


```solidity
error InvalidStreamSettings(uint64 streamId, uint64 denomination, uint8 peginConfirmations, uint8 pegoutConfirmations);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`streamId`|`uint64`|The stream ID|
|`denomination`|`uint64`|The denomination of the stream|
|`peginConfirmations`|`uint8`|The number of peg-in confirmations|
|`pegoutConfirmations`|`uint8`|The number of peg-out confirmations|

### InvalidStreamSettingsLength
Thrown when the stream settings length is invalid


```solidity
error InvalidStreamSettingsLength(uint256 actualLength, uint256 expectedLength);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`actualLength`|`uint256`|The number of stream settings|
|`expectedLength`|`uint256`|The number of stream settings|

