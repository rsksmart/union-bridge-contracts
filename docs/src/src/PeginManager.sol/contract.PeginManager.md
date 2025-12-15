# PeginManager
[Git Source](https://github.com/temp-rsk/bitvmx-union-bridge-contracts/blob/96535706e496364789ce242b18e17052bb6e424e/src/PeginManager.sol)

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

*This function can only be called once during contract deployment*


```solidity
function initialize(
    address _initialOwner,
    address payable _bridgeAddress,
    ICommitteeRegistry _committeeRegistry,
    IBitcoinManager _bitcoinManager,
    IRbtcBridge _rbtcBridge
) public virtual initializer;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_initialOwner`|`address`|The initial owner of the contract|
|`_bridgeAddress`|`address payable`|The address of the pow-peg bridge contract|
|`_committeeRegistry`|`ICommitteeRegistry`|The committee registry contract address|
|`_bitcoinManager`|`IBitcoinManager`|The Bitcoin manager contract address|
|`_rbtcBridge`|`IRbtcBridge`|The RbtcBridge contract for minting RBTC|


### getAcceptPegin

Gets the accept peg-in transaction id for a given request peg-in transaction id


```solidity
function getAcceptPegin(bytes32 _requestPeginTxid) external view returns (bytes32);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_requestPeginTxid`|`bytes32`|The request peg-in transaction id|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|The accept peg-in transaction id|


### getRequestPeginTempInfo

Gets the temporary peg-in information for a given request peg-in transaction id


```solidity
function getRequestPeginTempInfo(bytes32 _btcTxid) external view returns (RequestPeginTempInfo memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_btcTxid`|`bytes32`|The request peg-in transaction id|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`RequestPeginTempInfo`|The temporary peg-in information|


### getRequestPeginData

Generates request peg-in data including temporary Bitcoin address and member dispute keys

*This address is used for the initial peg-in request transaction*

*The dispute keys are returned in the same order as committee members*


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
|`_rootstockDepositAddress`|`address`|The Rootstock address where RBTC will be minted|
|`_value`|`uint64`|The amount in satoshis for determining the appropriate stream|
|`_btcReimbursementPubKey`|`bytes32`|The Bitcoin public key for reimbursement transactions|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`bitcoinDepositAddress`|`string`|The generated Bitcoin deposit address|
|`packetNumber`|`uint64`|The packet number for this peg-in request|
|`memberDisputeKeys`|`bytes32[]`|Array of dispute keys (covenant keys) for each committee member in order|
|`availableSlots`|`uint64`||


### requestPegin

Requests a peg-in operation by providing an SPV proof of the Bitcoin transaction

*This function validates the peg-in request transaction and initiates the peg-in process*

*The transaction must have at least 2 outputs: one P2TR output and one OP_RETURN output*

*Emits the PeginRequested event*

*Only callable when contract is unpaused*


```solidity
function requestPegin(BtcTxSPVProof calldata _requestPeginTxSPVProof) external nonReentrant whenNotPaused;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_requestPeginTxSPVProof`|`BtcTxSPVProof`|The SPV proof containing the Bitcoin transaction and merkle proof|


### _validateRequestPeginProof


```solidity
function _validateRequestPeginProof(BtcTxSPVProof calldata _requestPeginTxSPVProof)
    internal
    view
    returns (bytes32 requestPeginTxid);
```

### _extractPeginData


```solidity
function _extractPeginData(BtcTxSPVProof calldata _requestPeginTxSPVProof)
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

### _validatePeginTransaction


```solidity
function _validatePeginTransaction(
    BtcTxSPVProof calldata _requestPeginTxSPVProof,
    address rskDestinationAddress,
    bytes32 btcReimbursementPubKey,
    bytes memory committeePubKey,
    Stream memory stream,
    bytes32 requestPeginTxid
) internal view;
```

### acceptPegin

Accepts a peg-in operation by providing an SPV proof of the accept peg-in transaction

*This function validates the accept peg-in transaction, it must spend the output from the request peg-in transaction*

*Updates the stream position to ACCEPTED and stores the peg-in transaction in the stream*

*Emits the PeginAccepted event*

*Only callable when contract is unpaused*


```solidity
function acceptPegin(BtcTxSPVProof calldata _peginAcceptedTxSPVProof) external nonReentrant whenNotPaused;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_peginAcceptedTxSPVProof`|`BtcTxSPVProof`|The SPV proof containing the accept peg-in Bitcoin transaction|


### _storePegin


```solidity
function _storePegin(
    bytes32 _requestPeginTxid,
    bytes32 _blockHash,
    bytes32 _acceptPegintxid,
    BtcTxOut memory _acceptPeginTxOutput
) internal;
```

### getStreamPositionByRequestPegin

Gets the stream position information for a given request peg-in transaction id

*Looks up the corresponding accept peg-in txid and queries the StreamManager*


```solidity
function getStreamPositionByRequestPegin(bytes32 _requestPeginTxid) external view returns (StreamPosition memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_requestPeginTxid`|`bytes32`|The request peg-in Bitcoin transaction id to look up|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`StreamPosition`|The stream position information|


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


