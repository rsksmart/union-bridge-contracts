# StreamManager
[Git Source](https://github.com/rsksmart/union-bridge-contracts/blob/b56fdca4d854a3d344854107131d121e04834d63/src/StreamManager.sol)

**Inherits:**
[IStreamManager](/src/interfaces/IStreamManager.sol/interface.IStreamManager.md), [BaseProxy](/src/BaseProxy.sol/abstract.BaseProxy.md)

Manages streams for the union bridge system

*Handles stream creation, packet management, and slot allocation for peg-in/peg-out operations*

*Each stream represents a specific Bitcoin denomination with its own packet and slot management*


## State Variables
### streams

```solidity
Stream[] internal streams;
```


### packets
Mapping from stream ID to array of packets for that stream

*Each packet contains committee information for processing transactions*


```solidity
mapping(uint64 streamId => Packet[]) public packets;
```


### slots

```solidity
mapping(uint64 streamId => mapping(uint64 packetNumber => Slot[])) internal slots;
```


### filledSlots
Mapping from stream ID to array of historical filled slots for that stream

*The index should be used to get the next filled slot for peg-out processing*


```solidity
mapping(uint64 streamId => SlotLocation[]) filledSlots;
```


### nextPegoutSlotIndex

```solidity
mapping(uint64 streamId => uint64 index) nextPegoutSlotIndex;
```


### isPegoutInProcess
Mapping from stream ID to know if there's a pegout in process for that stream


```solidity
mapping(uint64 streamId => bool pegoutInProcess) isPegoutInProcess;
```


### streamPositions
Mapping from accept peg-in transaction ID to stream position

*Tracks the position and status of each peg operation*


```solidity
mapping(bytes32 acceptPeginTxid => StreamPosition) internal streamPositions;
```


### bitcoinManager
The Bitcoin manager contract that handles Bitcoin transaction operations

*Used to calculate enabler output scripts for packets*


```solidity
IBitcoinManager public bitcoinManager;
```


### accessManager
The access manager contract that manages access control

*Used to check access control for sensitive operations*


```solidity
IAccessManager public accessManager;
```


### securityBondPercentage

```solidity
mapping(Role role => uint16 percentage) public securityBondPercentage;
```


### disablementPaymentsPerChallenge

```solidity
uint256 public disablementPaymentsPerChallenge;
```


### minimumSecurityDeposit

```solidity
uint256 public minimumSecurityDeposit;
```


## Functions
### initialize

Initializes the streams with their denominations and parameters

*Creates streams for each denomination with default security bond and confirmation settings*


```solidity
function initialize(
    address _initialOwner,
    IAccessManager _accessManager,
    IBitcoinManager _bitcoinManager,
    StreamManagerSettings memory _settings
) public virtual initializer;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_initialOwner`|`address`|The address that will be set as the initial owner|
|`_accessManager`|`IAccessManager`|The address of the AccessManager contract|
|`_bitcoinManager`|`IBitcoinManager`|The BitcoinManager contract address|
|`_settings`|`StreamManagerSettings`|Struct with the settings for the StreamManager including security bond percentages|


### initializeStreams

Initializes the streams with the given settings


```solidity
function initializeStreams(StreamSettings[] memory _streamSettings) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_streamSettings`|`StreamSettings[]`|Array of structs with the settings for each stream including confirmation counts and timelock settings|


### _validateTimelockSettings


```solidity
function _validateTimelockSettings(TimelockSettings memory _timelockSettings) internal pure;
```

### createNewPacket

Creates a new packet for a stream

*Can only be called by the CommitteeRegistry when a new committee is formed*


```solidity
function createNewPacket(
    uint64 _streamId,
    uint128 _committeeId,
    bytes calldata _committeePubKey,
    bytes32[] memory _disputeKeys
) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_streamId`|`uint64`|The ID of the stream to create a packet for|
|`_committeeId`|`uint128`|The ID of the committee that will process this packet|
|`_committeePubKey`|`bytes`|The public key of the committee for Bitcoin operations|
|`_disputeKeys`|`bytes32[]`|The dispute keys (covenant public keys) for the committee members|


### _createNewPacket


```solidity
function _createNewPacket(
    uint64 _streamId,
    uint128 _committeeId,
    bytes memory _committeePubKey,
    bytes32[] memory _disputeKeys
) internal;
```

### getStream

Gets a stream by its denomination


```solidity
function getStream(uint64 _denomination) external view returns (Stream memory);
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
function getStreamById(uint64 _streamId) external view returns (Stream memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_streamId`|`uint64`|The ID of the stream|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`Stream`|The stream data for the given ID|


### _getStreamById


```solidity
function _getStreamById(uint64 _streamId) internal view returns (Stream storage);
```

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
function getPacket(uint64 _streamId, uint64 _packetNumber) public view returns (Packet memory);
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


### _getNextPegoutSlotLocation


```solidity
function _getNextPegoutSlotLocation(uint64 _streamId) internal view returns (SlotLocation memory);
```

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

*Can only be called by the PegManager*


```solidity
function lockSlot(uint64 _streamId) external returns (Slot memory, uint64);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_streamId`|`uint64`|The ID of the stream|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`Slot`|slot The locked slot data|
|`<none>`|`uint64`|packetNumber The packet number containing the slot|


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


### _getPacketSlotsLength

Gets the length of the slots in a packet


```solidity
function _getPacketSlotsLength(uint64 _streamId, uint64 _packetNumber) internal view returns (uint64);
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
    StreamPosition memory _streamPosition,
    uint64 _acceptPeginAmount,
    bytes32 _acceptPeginTx,
    bytes memory _scriptPubKey
) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_streamPosition`|`StreamPosition`||
|`_acceptPeginAmount`|`uint64`|The amount of the accept peg-in transaction in satoshis|
|`_acceptPeginTx`|`bytes32`|The transaction ID of the accept peg-in transaction|
|`_scriptPubKey`|`bytes`|The scriptPubKey of the accept peg-in taptree output|


### blockSlot

Blocks a reserved slot due to timeout or refund proof

*Updates the slot state from RESERVED to BLOCKED and sets peg status to BLOCKED*


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


### getCommitteePubKey

Retrieves the committee public key for a specific packet


```solidity
function getCommitteePubKey(uint64 _streamId, uint64 _packetNumber) external view returns (bytes memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_streamId`|`uint64`|The ID of the stream|
|`_packetNumber`|`uint64`|The index of the packet within the stream|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes`|bytes The committee public key for this packet (33 bytes)|


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


### _markSlotAsFinished


```solidity
function _markSlotAsFinished(uint64 _streamId, uint64 _packetNumber) internal returns (bool packetClosed);
```

### _pushToFilledSlotList


```solidity
function _pushToFilledSlotList(StreamPosition memory _streamPosition) internal;
```

### _closePacketIfLastSlot


```solidity
function _closePacketIfLastSlot(uint64 _streamId, uint64 _packetNumber) internal returns (bool);
```

### _getSlot


```solidity
function _getSlot(uint64 _streamId, uint64 _packetNumber, uint64 _slotId) internal view returns (Slot storage);
```

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


### getMinimumDeposit

Gets the minimum deposit required for a specific denomination and role


```solidity
function getMinimumDeposit(StreamDenomination _denomination, Role _role) public view returns (uint256);
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
function setTimelockSettings(uint64 _streamId, TimelockSettings memory _timelockSettings)
    external
    streamExists(_streamId)
    onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_streamId`|`uint64`|The ID of the stream|
|`_timelockSettings`|`TimelockSettings`|The timelock settings to set|


### setPeginConfirmations

Sets the number of confirmations required for peg-in transactions

*Only callable by the contract owner*


```solidity
function setPeginConfirmations(uint64 _streamId, uint8 _confirmations) external streamExists(_streamId) onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_streamId`|`uint64`|The ID of the stream|
|`_confirmations`|`uint8`|The number of confirmations required for peg-in transactions|


### setPegoutConfirmations

Sets the number of confirmations required for peg-out transactions

*Only callable by the contract owner*


```solidity
function setPegoutConfirmations(uint64 _streamId, uint8 _confirmations) external streamExists(_streamId) onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_streamId`|`uint64`|The ID of the stream|
|`_confirmations`|`uint8`|The number of confirmations required for peg-out transactions|


### setSecurityBondPercentage

Sets the security bond percentage for a specific role

*The percentage must be between 0 and 10000, where 10000 represents 100%*


```solidity
function setSecurityBondPercentage(Role _role, uint16 _percentage) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_role`|`Role`|The role for which to set the security bond percentage|
|`_percentage`|`uint16`|The new security bond percentage to set|


### _setSecurityBondPercentage


```solidity
function _setSecurityBondPercentage(Role _role, uint16 _percentage) internal;
```

### setMinimumSecurityDeposit

Sets the minimum security deposit required for the system

*Only callable by the contract owner*


```solidity
function setMinimumSecurityDeposit(uint256 _cost) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_cost`|`uint256`|The new minimum security deposit in wei|


### _setMinimumSecurityDeposit


```solidity
function _setMinimumSecurityDeposit(uint256 _cost) internal;
```

### setDisablementPaymentsPerChallenge

Sets the disablement payments cost per challenge, this is used to calculate the minimum deposit for a role

*Can only be called by the owner*


```solidity
function setDisablementPaymentsPerChallenge(uint256 _cost) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_cost`|`uint256`|The new disablement payments per challenge in wei|


### _setDisablementPaymentsPerChallenge


```solidity
function _setDisablementPaymentsPerChallenge(uint256 _cost) internal;
```

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


### _setPegStatus


```solidity
function _setPegStatus(bytes32 _acceptPeginTxid, PegStatus _newStatus) internal;
```

### streamExists


```solidity
modifier streamExists(uint64 _streamId);
```

### _streamExists


```solidity
function _streamExists(uint64 _streamId) internal view;
```

### restartStreamPointers_TESTNET


```solidity
function restartStreamPointers_TESTNET(uint64 _streamId) external onlyOwner;
```

