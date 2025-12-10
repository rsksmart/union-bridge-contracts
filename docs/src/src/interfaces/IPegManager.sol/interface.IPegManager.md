# IPegManager
[Git Source](https://github.com/temp-rsk/bitvmx-union-bridge-contracts/blob/2c7f90ba21d83a98b646123c60d27a00fe0644fd/src/interfaces/IPegManager.sol)

Interface for managing peg-in and peg-out operations in the union bridge

*This interface provides functions for processing Bitcoin to RSK and RSK to Bitcoin transfers*

*Handles the complete lifecycle of peg operations including request, acceptance, and completion*


## Functions
### setStreamManager

Sets the stream manager contract address

*Only callable by the contract owner*


```solidity
function setStreamManager(IStreamManager _streamManager) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_streamManager`|`IStreamManager`|The address of the stream manager contract|


### setSignatureManager

Sets the signature manager contract address

*Only callable by the contract owner*


```solidity
function setSignatureManager(ISignatureManager _signatureManager) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_signatureManager`|`ISignatureManager`|The address of the signature manager contract|


### getTemporaryPeginAddress

Generates a temporary Bitcoin address for peg-in operations

*Creates a Taproot address with committee and user reimbursment paths for secure peg-in*


```solidity
function getTemporaryPeginAddress(address _rootstockDepositAddress, uint64 _value, bytes32 _btcReimbursementPubKey)
    external
    returns (string memory temporaryPeginAddress);
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


### getStreamPosition

Retrieves the stream position information for a given Bitcoin transaction id


```solidity
function getStreamPosition(bytes32 btcTxid) external view returns (StreamPosition memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`btcTxid`|`bytes32`|The Bitcoin transaction id to look up|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`StreamPosition`|The stream position containing stream, packet, slot, and status information|


### requestPegin

Registers a peg-in request transaction from Bitcoin

*Validates the SPV proof and initiates the peg-in process*

*Emits PeginRequested event upon successful registration*


```solidity
function requestPegin(BtcTxSPVProof calldata _peginRequestTxSPVProof) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_peginRequestTxSPVProof`|`BtcTxSPVProof`|The BTC SPV proof of the peg-in request transaction|


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


### getPegoutTempInfo

Gets temporary information stored during peg-out processing


```solidity
function getPegoutTempInfo(bytes32 acceptPeginTxid) external view returns (PegoutTempInfo memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`acceptPeginTxid`|`bytes32`|The accept peg-in transaction id|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`PegoutTempInfo`|The temporary information needed for peg-out processing|


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


### tryPegout

Initiates a peg-out request to Bitcoin

*Requires payment in RBTC and will revert if no filled slot is available*

*Emits PegoutRequested event upon successful initiation*


```solidity
function tryPegout(bytes calldata _userPubKey) external payable;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_userPubKey`|`bytes`|The user's compressed public key that will receive the Bitcoin funds|


### registerUserTake

Registers the Bitcoin peg-out transaction to the user account

*Validates the SPV proof and completes the peg-out process*

*Emits PegoutRegistered event upon successful registration*


```solidity
function registerUserTake(BtcTxSPVProof calldata _pegoutTxSPVProof) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_pegoutTxSPVProof`|`BtcTxSPVProof`|The BTC SPV proof of the peg-out transaction|


### getPegoutTxid

Gets the peg-out signature hash for a specific stream, packet, and slot


```solidity
function getPegoutTxid(uint64 streamId, uint64 packetNumber, uint64 slotId) external view returns (bytes32);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`streamId`|`uint64`|The stream identifier|
|`packetNumber`|`uint64`|The packet number within the stream|
|`slotId`|`uint64`|The slot identifier within the packet|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|The peg-out signature hash|


### setUserTakeTimeout

Sets User Take Timeout

*Allows the contract owner to update the timeout for user take actions*

*Emits UserTakeTimeoutUpdated event upon successful update*

*Reverts if the timeout is zero*


```solidity
function setUserTakeTimeout(uint256 _timeout) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_timeout`|`uint256`|The new timeout value in seconds|


### setOperatorTakeTimeout

Sets Operator Take Timeout

*Allows the contract owner to update the timeout for operator take actions*

*Emits OperatorTakeTimeoutUpdated event upon successful update*

*Reverts if the timeout is zero*


```solidity
function setOperatorTakeTimeout(uint256 _timeout) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_timeout`|`uint256`|The new timeout value in seconds|


### userTakeTimeout

Gets the current timeout duration for user take operations


```solidity
function userTakeTimeout() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The timeout duration in seconds|


### operatorTakeTimeout

Gets the current timeout duration for operator take operations


```solidity
function operatorTakeTimeout() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The timeout duration in seconds|


### registerOperatorTake

Registers the Bitcoin peg-out transaction to the operator account

*Validates the SPV proof and marks the slot as paid when operator takes over*

*Only callable when the peg status is OPERATOR_TAKE*

*Emits PegoutRegistered event upon successful deposit*


```solidity
function registerOperatorTake(BtcTxSPVProof calldata _pegoutTxSPVProof) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_pegoutTxSPVProof`|`BtcTxSPVProof`|The BTC SPV proof of the operator take peg-out transaction|


### triggerOperatorTake

Triggers the operator take process for a peg-out when not all committee members sign within timeout

*This function can be called after a User Take expiration or after an Operator Take expiration*

*Each case has its own timeout and before triggering the operator take (after a User Take expiration)*

*signatures should be checked to see if the User Take was already signed*

*Partial signatures are used to skip those operators that have not signed the User Take*

*Emits OperatorTakeTriggered event upon successful triggering*


```solidity
function triggerOperatorTake(bytes32 _pegoutTxid) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_pegoutTxid`|`bytes32`|The transaction id of the peg-out request|


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
    bytes32 indexed peginRequestTxid,
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
|`peginRequestTxid`|`bytes32`|The hash of the original peg-in request transaction|
|`vout`|`uint64`|The output index of the transaction|
|`streamPosition`|`StreamPosition`|The final position of funds in the stream system|
|`speedUpPubKey`|`bytes32`|The public key for speed-up transactions|
|`rskDestinationAddress`|`address`|The RSK address that received the RBTC|
|`rbtcAmount`|`uint256`|The amount of RBTC minted|
|`utxoScriptPubKey`|`bytes`|The script pubkey of the UTXO|

### PegoutRequested
Event emitted when a peg-out is successfully requested


```solidity
event PegoutRequested(
    bytes userPubKey,
    uint256 indexed committeeId,
    BitcoinSignatureData pegoutSignatureData,
    uint64 streamId,
    uint64 packetNumber,
    uint64 slotId,
    uint64 amount,
    bytes32 pegoutId
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`userPubKey`|`bytes`|The user's public key that will receive the Bitcoin funds|
|`committeeId`|`uint256`|The ID of the committee responsible for this peg-out|
|`pegoutSignatureData`|`BitcoinSignatureData`|The signature data for committee signing|
|`streamId`|`uint64`|The stream ID where the funds originated|
|`packetNumber`|`uint64`|The packet number within the stream|
|`slotId`|`uint64`|The slot ID within the packet|
|`amount`|`uint64`|The amount being peg-out in satoshis|
|`pegoutId`|`bytes32`|The unique identifier for this peg-out operation|

### PegoutRegistered
Event emitted when a peg-out is successfully registered


```solidity
event PegoutRegistered(
    bytes32 indexed blockHash,
    bytes32 indexed txid,
    bytes32 indexed acceptPeginTxid,
    uint128 committeeId,
    uint64 streamId,
    uint64 packetNumber,
    uint64 slotId
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`blockHash`|`bytes32`|The Bitcoin block hash containing the peg-out transaction|
|`txid`|`bytes32`|The hash of the peg-out transaction|
|`acceptPeginTxid`|`bytes32`|The hash of the original accept peg-in transaction|
|`committeeId`|`uint128`|The ID of the committee responsible for this peg-out|
|`streamId`|`uint64`|The stream ID where the funds originated|
|`packetNumber`|`uint64`|The packet number within the stream|
|`slotId`|`uint64`|The slot ID within the packet|

### UserTakeTimeoutUpdated
Event emitted when the user take timeout is updated


```solidity
event UserTakeTimeoutUpdated(uint256 newTimeout);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newTimeout`|`uint256`|The new timeout duration in seconds|

### OperatorTakeTimeoutUpdated
Event emitted when the operator take timeout is updated


```solidity
event OperatorTakeTimeoutUpdated(uint256 newTimeout);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newTimeout`|`uint256`|The new timeout duration in seconds|

### OperatorTakeTriggered
Event emitted when operator take is triggered for a peg-out


```solidity
event OperatorTakeTriggered(
    bytes32 pegoutTxid, PegoutTempInfo pegoutInfo, StreamPosition streamPosition, uint256 updatedAt, uint256 expireAt
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`pegoutTxid`|`bytes32`|The transaction id of the peg-out request|
|`pegoutInfo`|`PegoutTempInfo`|Complete pegout temporary information including operator details|
|`streamPosition`|`StreamPosition`|Stream position information including slot ID|
|`updatedAt`|`uint256`|The timestamp when the operator take was triggered|
|`expireAt`|`uint256`|The timestamp when the operator take timeout expires|

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

### StreamManagerUpdated
Event emitted when the stream manager contract address is updated


```solidity
event StreamManagerUpdated(IStreamManager _streamManager);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_streamManager`|`IStreamManager`|The stream manager contract address|

### SignatureManagerUpdated
Event emitted when the signature manager contract address is updated


```solidity
event SignatureManagerUpdated(ISignatureManager _signatureManager);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_signatureManager`|`ISignatureManager`|The signature manager contract address|

## Errors
### BitcoinManagerAddressZero
Thrown when the Bitcoin manager address is set to zero


```solidity
error BitcoinManagerAddressZero();
```

### CommitteeRegistryAddressZero
Thrown when the committee registry address is set to zero


```solidity
error CommitteeRegistryAddressZero();
```

### SignatureManagerAddressZero
Thrown when the signature manager address is set to zero


```solidity
error SignatureManagerAddressZero();
```

### StreamManagerAddressZero
Thrown when the stream manager address is set to zero


```solidity
error StreamManagerAddressZero();
```

### MemberRegistryAddressZero
Thrown when the member registry address is set to zero


```solidity
error MemberRegistryAddressZero();
```

### PegoutRequestAmountExceedsUint64Limit
Thrown when peg-out request amount exceeds uint64 limit


```solidity
error PegoutRequestAmountExceedsUint64Limit(uint256 amount);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|The amount that exceeded the limit|

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

### IncorrectInputsNumber
Thrown when the number of inputs doesn't match the expected count


```solidity
error IncorrectInputsNumber(uint256 actual, uint256 expected);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`actual`|`uint256`|The actual number of inputs|
|`expected`|`uint256`|The expected number of inputs|

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

### InvalidCompressedPubKey
Thrown when the provided public key is not in valid compressed format


```solidity
error InvalidCompressedPubKey(bytes userPubKey);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`userPubKey`|`bytes`|The invalid public key that was provided|

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

### IncorrectVout
Thrown when the output index (vout) doesn't match the expected value


```solidity
error IncorrectVout(uint32 actual, uint32 expected);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`actual`|`uint32`|The actual vout value|
|`expected`|`uint32`|The expected vout value|

### IncorrectOutputScript
Thrown when the output script doesn't match the expected format


```solidity
error IncorrectOutputScript(bytes actual, bytes expected);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`actual`|`bytes`|The actual script bytes|
|`expected`|`bytes`|The expected script bytes|

### InvalidTimeout
Thrown when an invalid timeout value is provided (zero timeout)


```solidity
error InvalidTimeout(uint256 timeout);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`timeout`|`uint256`|The invalid timeout value that was provided|

### InvalidPegStatus
Thrown when the peg status is not valid for the current operation


```solidity
error InvalidPegStatus(PegStatus actual);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`actual`|`PegStatus`|The actual peg status that was found|

### UserTakeTimeoutNotExpired
Thrown when trying to trigger operator take before user take timeout has expired


```solidity
error UserTakeTimeoutNotExpired(uint256 createdAt, uint256 expireAt);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`createdAt`|`uint256`|The timestamp when the user take was created|
|`expireAt`|`uint256`|The timestamp when the user take timeout expires|

### UserTakeAlreadySigned
Thrown when trying to trigger operator take but user take was already signed


```solidity
error UserTakeAlreadySigned(bytes32 pegoutTxid);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`pegoutTxid`|`bytes32`|The signature hash of the peg-out request|

### OperatorTakeTimeoutNotExpired
Thrown when trying to trigger operator take before operator take timeout has expired


```solidity
error OperatorTakeTimeoutNotExpired(uint256 createdAt, uint256 expireAt);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`createdAt`|`uint256`|The timestamp when the operator take was updated|
|`expireAt`|`uint256`|The timestamp when the operator take timeout expires|

### PegoutTxidNotFound
Thrown when a peg-out signature hash is not found in the system


```solidity
error PegoutTxidNotFound(bytes32 pegoutTxid);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`pegoutTxid`|`bytes32`|The signature hash that was not found|

### OperatorTakeAddressNotMatch
Thrown when the operator address does not match the expected operator that should advance the funds


```solidity
error OperatorTakeAddressNotMatch(address expectedOperator, address actualOperator);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`expectedOperator`|`address`|The expected operator address that should take the pegout|
|`actualOperator`|`address`|The actual operator address that was provided|

