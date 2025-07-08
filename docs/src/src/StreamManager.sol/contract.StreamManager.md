# StreamManager
[Git Source](https://github.com/FairgateLabs/bitvmx-union-bridge-contracts/blob/88ae00b3e8fb636de955be6f15b3c84ce2cc3729/src/StreamManager.sol)

**Inherits:**
[IStreamManager](/src/interfaces/IStreamManager.sol/interface.IStreamManager.md), [AccessControl](/src/AccessControl.sol/contract.AccessControl.md)

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
mapping(uint64 streamId => mapping(uint64 packerNumber => Slot[])) internal slots;
```


### committeeRegistry
The committee registry contract that manages committee membership

*Used to create new packets when committees are formed*


```solidity
ICommitteeRegistry public committeeRegistry;
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
    IPegManager _pegManager,
    ICommitteeRegistry _committeeRegistry,
    uint64[] memory _denominations,
    StreamManagerSettings memory _settings
) public virtual initializer;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_initialOwner`|`address`|The address that will be set as the initial owner|
|`_pegManager`|`IPegManager`|The PegManager contract address|
|`_committeeRegistry`|`ICommitteeRegistry`|The CommitteeRegistry contract address|
|`_denominations`|`uint64[]`|Array of Bitcoin denominations in satoshis for each stream|
|`_settings`|`StreamManagerSettings`|The settings for the StreamManager including confirmation counts and security bond percentages|


### createNewPacket

Creates a new packet for a stream

*Can only be called by the CommitteeRegistry when a new committee is formed*


```solidity
function createNewPacket(uint64 _streamId, uint256 _committeeId, bytes32 _committeePubKey)
    external
    onlyCommitteeRegistry;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_streamId`|`uint64`|The ID of the stream to create a packet for|
|`_committeeId`|`uint256`|The ID of the committee that will process this packet|
|`_committeePubKey`|`bytes32`|The public key of the committee for Bitcoin operations|


### _createNewPacket


```solidity
function _createNewPacket(uint64 _streamId, uint256 _committeeId, bytes32 _committeePubKey) internal;
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

Gets the total number of streams


```solidity
function getStreamsLength() external view returns (uint64);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint64`|The number of streams in the system|


### getPacketsLength

Gets the number of packets in a stream


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
|`<none>`|`uint64`|The number of packets in the stream|


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
function getAvailablePeginCommitteeId(uint64 _streamId) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_streamId`|`uint64`|The ID of the stream|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The committee ID, or 0 if no current packet|


### fillSlot


```solidity
function fillSlot(uint64 _streamId, uint64 _packetNumber, Slot memory slot) internal returns (uint64 slotId);
```

### lockSlot

Returns the first filled slot, locks it, and updates the peg-out pointers

*Can only be called by the PegManager*


```solidity
function lockSlot(uint64 _streamId) external onlyPegManager returns (Slot memory, uint64 packetNumber);
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


### fillAcceptPeginTx

Looks for the first empty slot and assigns the peg-in transaction in prepared state

*Can only be called by the PegManager*


```solidity
function fillAcceptPeginTx(
    uint64 _streamId,
    uint64 _packetNumber,
    uint64 _acceptPeginAmount,
    bytes32 _acceptPeginTx,
    bytes memory _scriptPubKey
) external onlyPegManager returns (uint64);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_streamId`|`uint64`|The ID of the stream|
|`_packetNumber`|`uint64`|The packet number|
|`_acceptPeginAmount`|`uint64`|The amount of the accept peg-in transaction|
|`_acceptPeginTx`|`bytes32`|The hash of the accept peg-in transaction|
|`_scriptPubKey`|`bytes`|The script pub key for the transaction|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint64`|The slot ID that was filled|


### getCommitteeId

Gets the committee ID for a specific packet


```solidity
function getCommitteeId(uint64 _streamId, uint64 _packetNumber) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_streamId`|`uint64`|The ID of the stream|
|`_packetNumber`|`uint64`|The packet number|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The committee ID for the packet|


### getCommitteePubKey

Gets the committee public key for a specific packet


```solidity
function getCommitteePubKey(uint64 _streamId, uint64 _packetNumber) external view returns (bytes32);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_streamId`|`uint64`|The ID of the stream|
|`_packetNumber`|`uint64`|The packet number|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|The committee public key for the packet|


### completeSlot

Marks a slot as completed and stores the UserTake transaction hash

*Can only be called by the PegManager*


```solidity
function completeSlot(
    uint64 _streamId,
    uint64 _packetNumber,
    uint64 _slotId,
    bytes32 _acceptPeginTxHash,
    bytes32 _userTakeTx
) external onlyPegManager;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_streamId`|`uint64`|The ID of the stream|
|`_packetNumber`|`uint64`|The packet number|
|`_slotId`|`uint64`|The slot ID|
|`_acceptPeginTxHash`|`bytes32`|The hash of the accept peg-in transaction|
|`_userTakeTx`|`bytes32`|The hash of the UserTake transaction|


### _getSlot


```solidity
function _getSlot(uint64 _streamId, uint64 _packetNumber, uint64 _slotId) internal view returns (Slot storage);
```

### advanceSlot


```solidity
function advanceSlot(uint64 _streamId, uint64 _packetNumber, uint64 _slotId) external onlyPegManager;
```

### getMinimumDeposit


```solidity
function getMinimumDeposit(StreamDenomination _denomination, Role _role) public view returns (uint256);
```

### setPeginConfirmations

Sets the number of confirmations required for peg-in transactions

*Can only be called by the owner*


```solidity
function setPeginConfirmations(uint64 _streamId, uint8 _confirmations) external streamExists(_streamId) onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_streamId`|`uint64`|The ID of the stream|
|`_confirmations`|`uint8`|The number of confirmations required|


### setPegoutConfirmations

Sets the number of confirmations required for peg-out transactions

*Can only be called by the owner*


```solidity
function setPegoutConfirmations(uint64 _streamId, uint8 _confirmations) external streamExists(_streamId) onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_streamId`|`uint64`|The ID of the stream|
|`_confirmations`|`uint8`|The number of confirmations required|


### setCommitteeRegistry

Sets the committee registry contract address

*Can only be called by the owner*


```solidity
function setCommitteeRegistry(ICommitteeRegistry _committeeRegistry) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_committeeRegistry`|`ICommitteeRegistry`|The new committee registry contract address|


### setSecurityBondPercentage

Reverts if the role is NONE or if the percentage is 0 or greater than 10_000

*Sets the security bond percentage for a given role*


```solidity
function setSecurityBondPercentage(Role _role, uint16 _percentage) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_role`|`Role`|The role for which to set the security bond percentage|
|`_percentage`|`uint16`|The security bond percentage in 10_000 format (e.g. 1000 = 10%)|


### setMinimumSecurityDeposit


```solidity
function setMinimumSecurityDeposit(uint256 _cost) external onlyOwner;
```

### setDisablementPaymentsPerChallenge


```solidity
function setDisablementPaymentsPerChallenge(uint256 _cost) external onlyOwner;
```

### streamExists


```solidity
modifier streamExists(uint64 _streamId);
```

### onlyCommitteeRegistry


```solidity
modifier onlyCommitteeRegistry();
```

