# PeginManager
[Git Source](https://github.com/rsksmart/union-bridge-contracts/blob/68c14faa89612dfba1b7e9abf29455625661476f/src/PeginManager.sol)

**Inherits:**
[IPeginManager](/src/interfaces/IPeginManager.sol/interface.IPeginManager.md), [PegManagerBase](/src/PegManagerBase.sol/abstract.PegManagerBase.md)

Manages peg-in operations from Bitcoin to Rootstock


## State Variables
### acceptPegins

```solidity
mapping(bytes32 requestPeginTxid => bytes32 acceptPeginTxid) internal acceptPegins;
```


### peginTempInfo

```solidity
mapping(bytes32 requestPeginTxid => RequestPeginTempInfo tempInfo) internal peginTempInfo;
```


## Functions
### initialize

Initializes the PeginManager contract


```solidity
function initialize(
    address _initialOwner,
    address _accessManager,
    ICommitteeRegistry _committeeRegistry,
    IBitcoinManager _bitcoinManager,
    IRbtcBridge _rbtcBridge,
    IStreamManager _streamManager,
    ISignatureManager _signatureManager
) public virtual initializer;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_initialOwner`|`address`|The initial owner of the contract|
|`_accessManager`|`address`|The access manager contract address|
|`_committeeRegistry`|`ICommitteeRegistry`|The committee registry contract address|
|`_bitcoinManager`|`IBitcoinManager`|The Bitcoin manager contract address|
|`_rbtcBridge`|`IRbtcBridge`|The RbtcBridge contract for minting RBTC|
|`_streamManager`|`IStreamManager`|The stream manager contract address|
|`_signatureManager`|`ISignatureManager`|The signature manager contract address|


### getAcceptPegin

Gets the accept peg-in transaction id for a given request transaction id


```solidity
function getAcceptPegin(bytes32 _requestPeginTxid) external view returns (bytes32);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_requestPeginTxid`|`bytes32`||

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|The accept peg-in transaction id|


### getRequestPeginTempInfo

Gets temporary information stored during peg-in request processing


```solidity
function getRequestPeginTempInfo(bytes32 _btcTxid) external view returns (RequestPeginTempInfo memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_btcTxid`|`bytes32`||

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`RequestPeginTempInfo`|The temporary information needed for the accept phase|


### getRequestPeginData

Generates request peg-in data including temporary Bitcoin address and member dispute keys

*Creates a Taproot address with committee and user reimbursment paths for secure peg-in*


```solidity
function getRequestPeginData(address _rootstockDepositAddress, uint64 _value, bytes32 _btcReimbursementPubKey)
    external
    view
    returns (
        string memory bitcoinDepositAddress,
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
|`bitcoinDepositAddress`|`string`|temporaryPeginAddress The generated temporary Bitcoin address for deposit|
|`packetNumber`|`uint64`|The packet number for this peg-in request|
|`memberDisputeKeys`|`bytes32[]`|Array of dispute keys (covenant keys) for each committee member in order|
|`availableSlots`|`uint64`||


### requestPegin

Requests a peg-in operation by providing an SPV proof of the Bitcoin transaction

*This function validates the peg-in request transaction and initiates the peg-in process*


```solidity
function requestPegin(BtcTxSPVProof memory _requestPeginTxSPVProof) external nonReentrant whenNotPaused;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_requestPeginTxSPVProof`|`BtcTxSPVProof`|The SPV proof containing the Bitcoin transaction and merkle proof|


### _validateRequestPeginProof


```solidity
function _validateRequestPeginProof(BtcTxSPVProof memory _requestPeginTxSPVProof)
    internal
    view
    returns (bytes32 requestPeginTxid);
```

### _validatePeginP2TRAndOpReturn


```solidity
function _validatePeginP2TRAndOpReturn(BtcTxSPVProof memory _requestPeginTxSPVProof)
    internal
    view
    returns (
        uint64 packetNumber,
        address rskDestinationAddress,
        bytes32 btcReimbursementPubKey,
        Stream memory stream,
        bytes memory committeePubKey
    );
```

### _validatePeginEnablerAndBlockNumber


```solidity
function _validatePeginEnablerAndBlockNumber(
    BtcTxSPVProof memory _requestPeginTxSPVProof,
    bytes32 _btcReimbursementPubKey,
    bytes memory _committeePubKey,
    bytes memory _enablerScriptPubKey,
    Stream memory _stream,
    bytes32 _requestPeginTxid,
    uint128 _committeeId
) internal view returns (int256 blockNumber, BitcoinSignatureData memory acceptPeginSignatureData);
```

### _calculateAcceptPeginSignatureData


```solidity
function _calculateAcceptPeginSignatureData(
    bytes32 _btcReimbursementPubKey,
    uint128 _committeeId,
    bytes32 _requestPeginTxid,
    BtcTxSPVProof memory _requestPeginTxSPVProof,
    bytes memory _committeePubKey,
    bytes memory _enablerScriptPubKey
) internal view returns (BitcoinSignatureData memory acceptPeginSignatureData);
```

### _reserveSlot


```solidity
function _reserveSlot(uint64 _streamId, uint64 packetNumber, bytes32 _txid)
    internal
    returns (StreamPosition memory streamPos);
```

### userReimbursement

Registers a user reimbursement transaction from Bitcoin

*Validates the SPV proof and completes the user reimbursement process*


```solidity
function userReimbursement(BtcTxSPVProof memory _userReimbursementTxSPVProof, uint32 _reimbursementPeginVin)
    external
    nonReentrant
    whenNotPaused;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_userReimbursementTxSPVProof`|`BtcTxSPVProof`|The BTC SPV proof of the user reimbursement transaction|
|`_reimbursementPeginVin`|`uint32`|The input index of the reimbursement peg-in transaction|


### _verifyUserReimbursementTransaction


```solidity
function _verifyUserReimbursementTransaction(
    BtcTxSPVProof memory _userReimbursementTxSPVProof,
    bytes32 _requestPeginTxid,
    bytes32 _userReimbursementTxid,
    uint64 _streamId,
    uint32 _reimbursementPeginVin
) internal view;
```

### rejectPegin

Registers a reject peg-in transaction from Bitcoin

*Validates the SPV proof and registers the reject peg-in transaction*


```solidity
function rejectPegin(BtcTxSPVProof memory _rejectPeginTxSPVProof) external nonReentrant whenNotPaused;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_rejectPeginTxSPVProof`|`BtcTxSPVProof`|The BTC SPV proof of the reject peg-in transaction|


### _blockSlot


```solidity
function _blockSlot(StreamPosition memory _streamInfo, bytes32 _acceptPeginTxid) internal;
```

### _verifyRejectPeginTransaction


```solidity
function _verifyRejectPeginTransaction(
    BtcTxSPVProof memory _rejectPeginTxSPVProof,
    bytes32 _rejectPeginTxid,
    uint64 _streamId
) internal view;
```

### acceptPegin

Accepts and registers a Bitcoin peg-in transaction to the committee account

*Validates the SPV proof and completes the peg-in process*


```solidity
function acceptPegin(BtcTxSPVProof memory _peginAcceptedTxSPVProof) external nonReentrant whenNotPaused;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_peginAcceptedTxSPVProof`|`BtcTxSPVProof`|The BTC SPV proof of the accept peg-in transaction|


### _storePegin


```solidity
function _storePegin(
    bytes32 _requestPeginTxid,
    bytes32 _blockHash,
    bytes32 _acceptPeginTxid,
    BtcTxOut memory _acceptPeginTxOutput
) internal;
```

### getStreamPositionByRequestPegin

Retrieves the stream position information for a given request peg-in transaction id

*Looks up the corresponding accept peg-in txid and queries the StreamManager*


```solidity
function getStreamPositionByRequestPegin(bytes32 _requestPeginTxid) external view returns (StreamPosition memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_requestPeginTxid`|`bytes32`||

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`StreamPosition`|The stream position containing stream, packet, slot, and status information|


### _getStreamPositionByRequestPegin

*Internal helper to get stream position from request peg-in txid*


```solidity
function _getStreamPositionByRequestPegin(bytes32 _requestPeginTxid) internal view returns (StreamPosition memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_requestPeginTxid`|`bytes32`|The request peg-in transaction id|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`StreamPosition`|The stream position information|


