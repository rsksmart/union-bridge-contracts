# PegManager
[Git Source](https://github.com/FairgateLabs/bitvmx-union-bridge-contracts/blob/88ae00b3e8fb636de955be6f15b3c84ce2cc3729/src/PegManager.sol)

**Inherits:**
[IPegManager](/src/interfaces/IPegManager.sol/interface.IPegManager.md), [BaseProxy](/src/BaseProxy.sol/abstract.BaseProxy.md), [ProofValidator](/src/ProofValidator.sol/abstract.ProofValidator.md)

Manages peg-in and peg-out operations between Bitcoin and Rootstock

*This contract handles the complete lifecycle of Bitcoin peg operations including:
- Requesting peg-ins with SPV proofs
- Accepting peg-ins with committee signatures
- Processing peg-outs and associated committee signatures
- Managing temporary Bitcoin deposit addresses
- Coordinating with StreamManager for slot allocation
- Integrating with CommitteeRegistry for committee management*


## State Variables
### bitcoinManager
Bitcoin manager contract for Bitcoin transaction validation and address generation


```solidity
IBitcoinManager public bitcoinManager;
```


### streamManager
Stream manager contract for managing union bridge streams and slots


```solidity
IStreamManager public streamManager;
```


### committeeRegistry
Committee registry contract for managing committee and members


```solidity
ICommitteeRegistry public committeeRegistry;
```


### signatureManager
Signature manager contract for handling multi-signature operations


```solidity
ISignatureManager public signatureManager;
```


### userTakeTimeout
Timeout for user take operations


```solidity
uint256 public userTakeTimeout;
```


### operatorTakeTimeout
Timeout for operator take operations


```solidity
uint256 public operatorTakeTimeout;
```


### peginRequests

```solidity
mapping(bytes32 requestPeginTxHash => bytes32 acceptPeginTxhash) internal peginRequests;
```


### streamPosition

```solidity
mapping(bytes32 acceptPeginTxhash => StreamPosition streamPosition) internal streamPosition;
```


### peginTempInfo

```solidity
mapping(bytes32 requestPeginTxHash => RequestPeginTempInfo tempInfo) internal peginTempInfo;
```


### pegoutTempInfo

```solidity
mapping(bytes32 acceptPeginTxHash => PegoutTempInfo tempInfo) internal pegoutTempInfo;
```


### pegoutToPeginTxHash

```solidity
mapping(bytes32 pegoutSignatureHash => bytes32 acceptPeginTxHash) internal pegoutToPeginTxHash;
```


### pegoutSighashes

```solidity
mapping(bytes32 key => bytes32 pegoutSignatureHash) internal pegoutSighashes;
```


## Functions
### initialize

Initializes the PegManager contract

*This function can only be called once during contract deployment*


```solidity
function initialize(
    address _initialOwner,
    address payable _bridgeAddress,
    ICommitteeRegistry _committeeRegistry,
    IBitcoinManager _bitcoinManager,
    PegManagerSettings memory _settings
) public virtual initializer;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_initialOwner`|`address`|The initial owner of the contract|
|`_bridgeAddress`|`address payable`|The address of the pow-peg bridge contract|
|`_committeeRegistry`|`ICommitteeRegistry`|The committee registry contract address|
|`_bitcoinManager`|`IBitcoinManager`|The Bitcoin manager contract address|
|`_settings`|`PegManagerSettings`|The peg manager settings including timeouts|


### setStreamManager

Sets the stream manager contract address

*Only callable by the contract owner*


```solidity
function setStreamManager(IStreamManager _streamManager) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_streamManager`|`IStreamManager`|The stream manager contract address|


### setSignatureManager

Sets the signature manager contract address

*Only callable by the contract owner*


```solidity
function setSignatureManager(ISignatureManager _signatureManager) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_signatureManager`|`ISignatureManager`|The signature manager contract address|


### getPeginRequest

Gets the accept peg-in transaction hash for a given request peg-in transaction hash


```solidity
function getPeginRequest(bytes32 _requestPeginTxHash) external view returns (bytes32);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_requestPeginTxHash`|`bytes32`|The request peg-in transaction hash|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|The accept peg-in transaction hash|


### getRequestPeginTempInfo

Gets the temporary peg-in information for a given request peg-in transaction hash


```solidity
function getRequestPeginTempInfo(bytes32 _btcTxHash) external view returns (RequestPeginTempInfo memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_btcTxHash`|`bytes32`|The request peg-in transaction hash|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`RequestPeginTempInfo`|The temporary peg-in information|


### getPegoutTempInfo

Gets the temporary peg-out information for a given accept peg-in transaction hash


```solidity
function getPegoutTempInfo(bytes32 _acceptPeginTxHash) external view returns (PegoutTempInfo memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_acceptPeginTxHash`|`bytes32`|The accept peg-in transaction hash|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`PegoutTempInfo`|The temporary peg-out information|


### getTemporaryPeginAddress

Generates a temporary Bitcoin deposit address for peg-in operations

*This address is used for the initial peg-in request transaction*


```solidity
function getTemporaryPeginAddress(address _rootstockDepositAddress, uint64 _value, bytes32 _btcReimbursementPubKey)
    external
    view
    returns (string memory bitcoinDepositAddress);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_rootstockDepositAddress`|`address`|The Rootstock address where RBTC will be minted|
|`_value`|`uint64`|The amount in satoshis for determining the appropriate stream|
|`_btcReimbursementPubKey`|`bytes32`|The Bitcoin public key for reimbursement transactions|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`bitcoinDepositAddress`|`string`|The generated Bitcoin deposit address|


### requestPegin

Requests a peg-in operation by providing an SPV proof of the Bitcoin transaction

*This function validates the peg-in request transaction and initiates the peg-in process*

*The transaction must have at least 2 outputs: one P2TR output and one OP_RETURN output*

*Emits the PeginRequested event*


```solidity
function requestPegin(BtcTxSPVProof calldata _peginRequestTxSPVProof) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_peginRequestTxSPVProof`|`BtcTxSPVProof`|The SPV proof containing the Bitcoin transaction and merkle proof|


### _initAcceptPegin


```solidity
function _initAcceptPegin(
    bytes32 _committeePubKey,
    bytes32 _userXOnlyPubKey,
    bytes32 _requestPeginTxHash,
    address _rskDestinationAddress,
    PrevoutData memory _prevoutData,
    uint64 _streamId,
    uint64 _packetNumber
) internal;
```

### acceptPegin

Accepts a peg-in operation by providing an SPV proof of the accept peg-in transaction

*This function validates the accept peg-in transaction, it must spend the output from the request peg-in transaction*

*Updates the stream position to ACCEPTED and stores the peg-in transaction in the stream*

*Emits the PeginAccepted event*


```solidity
function acceptPegin(BtcTxSPVProof calldata _peginAcceptedTxSPVProof) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_peginAcceptedTxSPVProof`|`BtcTxSPVProof`|The SPV proof containing the accept peg-in Bitcoin transaction|


### _storePegin


```solidity
function _storePegin(
    bytes32 _requestPeginTxHash,
    StreamPosition memory streamInfo,
    bytes32 _blockHash,
    bytes32 _acceptPegintxHash,
    BtcTxOut memory _acceptPeginTxOutput
) internal;
```

### _validatePegoutRequest


```solidity
function _validatePegoutRequest(bytes calldata _userPubKey, uint256 amountInWei) internal pure;
```

### tryPegout

Initiates a peg-out operation by locking a slot and preparing the peg-out transaction

*This function LOCKS a slot in the appropriate stream and prepares the peg-out transaction*

*The user must send the exact amount of RBTC they want to peg-out*

*Emits the PegoutRequested event*


```solidity
function tryPegout(bytes calldata _userPubKey) external payable;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_userPubKey`|`bytes`|The user's compressed public key for the Bitcoin output|


### registerUserTake

Register a peg-out transaction from Bitcoin

*This function validates the peg-out transaction and marks the slot as COMPLETED*

*The transaction must spend the accept peg-in output and pay to the user's address*

*Emits the PegoutRegistered event*


```solidity
function registerUserTake(BtcTxSPVProof calldata _pegoutTxSPVProof) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_pegoutTxSPVProof`|`BtcTxSPVProof`|The BTC SPV proof of the peg-out transaction|


### getPegoutSignatureHash

Gets the peg-out signature hash for a specific stream, packet, and slot


```solidity
function getPegoutSignatureHash(uint64 streamId, uint64 packetNumber, uint64 slotId) external view returns (bytes32);
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


### getStreamPosition

Gets the stream position information for a given Bitcoin Pegin request transaction hash


```solidity
function getStreamPosition(bytes32 _acceptPeginTxHash) external view returns (StreamPosition memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_acceptPeginTxHash`|`bytes32`|The accept peg-in Bitcoin transaction hash|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`StreamPosition`|The stream position information|


### _getStreamPosition


```solidity
function _getStreamPosition(bytes32 _acceptPeginTxHash) internal view returns (StreamPosition memory);
```

### _storePegoutAndInitSignatures


```solidity
function _storePegoutAndInitSignatures(
    bytes32 _pegoutSignatureHash,
    uint64 _streamId,
    uint64 _packetNumber,
    uint64 _slotId
) internal returns (uint256);
```

### triggerOperatorTake

Triggers the operator take process for a peg-out when not all committee members sign within timeout

*This function can be called after a User Take expiration or after an Operator Take expiration*

*Each case has its own timeout and before triggering the operator take (after a User Take expiration)*

*signatures should be checked to see if the User Take was already signed*

*Partial signatures are used to skip those operators that have not signed the User Take*

*Emits OperatorTakeTriggered event upon successful triggering*


```solidity
function triggerOperatorTake(bytes32 _pegoutSignatureHash) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_pegoutSignatureHash`|`bytes32`|The signature hash of the peg-out request|


### registerOperatorTake

Deposits an operator take proof for a peg-out transaction

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


### setUserTakeTimeout

Sets the timeout duration for user take operations

*Only callable by the contract owner*

*Emits UserTakeTimeoutUpdated event upon successful update*


```solidity
function setUserTakeTimeout(uint256 _timeout) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_timeout`|`uint256`|The new timeout duration in seconds|


### setOperatorTakeTimeout

Sets the timeout duration for operator take operations

*Only callable by the contract owner*

*Emits OperatorTakeTimeoutUpdated event upon successful update*


```solidity
function setOperatorTakeTimeout(uint256 _timeout) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_timeout`|`uint256`|The new timeout duration in seconds|


