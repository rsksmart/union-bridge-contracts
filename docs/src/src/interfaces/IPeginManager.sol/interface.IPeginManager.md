# IPeginManager
[Git Source](https://github.com/temp-rsk/bitvmx-union-bridge-contracts/blob/13960dd321557c932048de4fc7353af5ceae0b8d/src/interfaces/IPeginManager.sol)

**Inherits:**
[IPausable](/src/interfaces/IPausable.sol/interface.IPausable.md)

Interface for managing peg-in operations


## Functions
### getRequestPeginData

Generates request peg-in data including temporary Bitcoin address and member dispute keys

*Creates a Taproot address with committee and user reimbursment paths for secure peg-in*

*Returns an array of dispute keys (covenant keys) for each committee member in order*


```solidity
function getRequestPeginData(address _rootstockDepositAddress, uint64 _value, bytes32 _btcReimbursementPubKey)
    external
    view
    returns (
        string memory temporaryPeginAddress,
        uint64 packetNumber,
        bytes32[] memory memberDisputeKeys,
        uint64 availableSlots
    );
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_rootstockDepositAddress`|`address`|The RSK address that will receive the RBTC|
|`_value`|`uint64`|The amount in satoshis to peg in (must match stream denomination)|
|`_btcReimbursementPubKey`|`bytes32`|The user's Bitcoin public key (x-coordinate only, 32 bytes)|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`temporaryPeginAddress`|`string`|The generated temporary Bitcoin address for deposit|
|`packetNumber`|`uint64`|The packet number for this peg-in request|
|`memberDisputeKeys`|`bytes32[]`|Array of dispute keys (covenant keys) for each committee member in order|
|`availableSlots`|`uint64`||


### getStreamPositionByRequestPegin

Retrieves the stream position information for a given request peg-in transaction id

*Looks up the corresponding accept peg-in txid and queries the StreamManager*


```solidity
function getStreamPositionByRequestPegin(bytes32 requestPeginTxid) external view returns (StreamPosition memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`requestPeginTxid`|`bytes32`|The request peg-in Bitcoin transaction id to look up|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`StreamPosition`|The stream position containing stream, packet, slot, and status information|


### requestPegin

Registers a peg-in request transaction from Bitcoin

*Validates the SPV proof and initiates the peg-in process*

*Emits PeginRequested event upon successful registration*


```solidity
function requestPegin(BtcTxSPVProof calldata _requestPeginTxSPVProof) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_requestPeginTxSPVProof`|`BtcTxSPVProof`|The BTC SPV proof of the peg-in request transaction|


### getAcceptPegin

Gets the accept peg-in transaction id for a given request transaction id


```solidity
function getAcceptPegin(bytes32 _btcTxid) external view returns (bytes32);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_btcTxid`|`bytes32`|The Bitcoin transaction id of the peg-in request|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|The accept peg-in transaction id|


### getRequestPeginTempInfo

Gets temporary information stored during peg-in request processing


```solidity
function getRequestPeginTempInfo(bytes32 btcTxid) external view returns (RequestPeginTempInfo memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`btcTxid`|`bytes32`|The Bitcoin transaction id of the peg-in request|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`RequestPeginTempInfo`|The temporary information needed for the accept phase|


### acceptPegin

Accepts and registers a Bitcoin peg-in transaction to the committee account

*Validates the SPV proof and completes the peg-in process*

*Emits PeginAccepted event upon successful acceptance*


```solidity
function acceptPegin(BtcTxSPVProof calldata _peginAcceptedTxSPVProof) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_peginAcceptedTxSPVProof`|`BtcTxSPVProof`|The BTC SPV proof of the accept peg-in transaction|


## Events
### PeginRequested
Event emitted when a peg-in request is successfully registered


```solidity
event PeginRequested(
    uint128 indexed committeeId,
    bytes32 indexed requestPeginTxid,
    bytes32 indexed acceptPeginTxid,
    uint64 vout,
    StreamPosition streamPosition,
    RequestPeginTempInfo requestPeginInfo,
    PrevoutData prevoutData,
    bytes acceptPeginSignatureMessage
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`committeeId`|`uint128`|The ID of the committee responsible for this peg-in|
|`requestPeginTxid`|`bytes32`|The hash of the peg-in request transaction|
|`acceptPeginTxid`|`bytes32`|The hash of the accept peg-in transaction|
|`vout`|`uint64`|The output index of the transaction|
|`streamPosition`|`StreamPosition`|The struct with the position information (stream, packet, slot, status)|
|`requestPeginInfo`|`RequestPeginTempInfo`|Temporary information needed for the accept phase|
|`prevoutData`|`PrevoutData`|Data about the previous output being spent|
|`acceptPeginSignatureMessage`|`bytes`|The signature message for committee signing|

### PeginAccepted
Event emitted when a peg-in is successfully accepted


```solidity
event PeginAccepted(
    bytes32 indexed blockHash,
    bytes32 indexed acceptPeginTxid,
    bytes32 indexed requestPeginTxid,
    uint64 vout,
    StreamPosition streamPosition,
    bytes32 speedUpPubKey,
    address rskDestinationAddress,
    uint256 rbtcAmount,
    bytes utxoScriptPubKey
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`blockHash`|`bytes32`|The Bitcoin block hash containing the accept transaction|
|`acceptPeginTxid`|`bytes32`|The hash of the accept peg-in transaction|
|`requestPeginTxid`|`bytes32`|The hash of the original peg-in request transaction|
|`vout`|`uint64`|The output index of the transaction|
|`streamPosition`|`StreamPosition`|The final position of funds in the stream system|
|`speedUpPubKey`|`bytes32`|The public key for speed-up transactions|
|`rskDestinationAddress`|`address`|The RSK address that received the RBTC|
|`rbtcAmount`|`uint256`|The amount of RBTC minted|
|`utxoScriptPubKey`|`bytes`|The script pubkey of the UTXO|

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

## Errors
### PeginAlreadyRequested
Thrown when a peg-in has already been requested for the given transaction


```solidity
error PeginAlreadyRequested(bytes32 btcTxid);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`btcTxid`|`bytes32`|The Bitcoin transaction id that was already requested|

### PeginNotRequested
Thrown when trying to process a peg-in that hasn't been requested


```solidity
error PeginNotRequested(bytes32 btcTxid);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`btcTxid`|`bytes32`|The Bitcoin transaction id that wasn't requested|

### InvalidAcceptPeginTxid
Thrown when the accept peg-in transaction id doesn't match the expected value


```solidity
error InvalidAcceptPeginTxid(bytes32 expected, bytes32 actual);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`expected`|`bytes32`|The expected transaction id|
|`actual`|`bytes32`|The actual transaction id received|

### PeginAlreadyAccepted
Thrown when a peg-in has already been accepted


```solidity
error PeginAlreadyAccepted(bytes32 btcTxid);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`btcTxid`|`bytes32`|The Bitcoin transaction id that was already accepted|

### IncorrectOutputsNumber
Thrown when the number of outputs doesn't match the expected count


```solidity
error IncorrectOutputsNumber(uint256 actual, uint256 expected);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`actual`|`uint256`|The actual number of outputs|
|`expected`|`uint256`|The expected number of outputs|

### InvalidLocktime
Thrown when the transaction locktime doesn't match the expected value


```solidity
error InvalidLocktime(uint256 actual, uint256 expected);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`actual`|`uint256`|The actual locktime value|
|`expected`|`uint256`|The expected locktime value|

### InvalidBtcTxVersion
Thrown when the Bitcoin transaction version doesn't match the expected value


```solidity
error InvalidBtcTxVersion(uint256 actual, uint256 expected);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`actual`|`uint256`|The actual version value|
|`expected`|`uint256`|The expected version value|

### BridgeExceededLockingCap
Thrown when the input amount exceeds the locking cap of the pow-peg bridge


```solidity
error BridgeExceededLockingCap(uint256 value, uint256 lockingCap);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`value`|`uint256`|The input amount that exceeded the locking cap|
|`lockingCap`|`uint256`|The locking cap of the pow-peg bridge|

