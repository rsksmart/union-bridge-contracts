# OperatorTakeManager
[Git Source](https://github.com/temp-rsk/bitvmx-union-bridge-contracts/blob/bd6b4a28bf5973e554d9b7a237190a44cdd46b38/src/OperatorTakeManager.sol)

**Inherits:**
[IOperatorTakeManager](/src/interfaces/IOperatorTakeManager.sol/interface.IOperatorTakeManager.md), [PegManagerBase](/src/PegManagerBase.sol/abstract.PegManagerBase.md)

Manages operator take flow: trigger, advance funds, reimbursement kickoff, operator take, operator won


## State Variables
### pegoutManager
The PegoutManager contract


```solidity
IPegoutManager public pegoutManager;
```


### takeTimeouts
Per-stream timeout settings indexed by stream ID


```solidity
mapping(uint256 => TakeTimeout) public takeTimeouts;
```


### sequenceNumber
The pegout ID sequence number incremented for each new triggerOperatorTake


```solidity
uint256 public sequenceNumber;
```


### cancelUserTakeTxBlockNumber
Mapping that connects the blockNumber where the cancel user take tx was mined with its corresponding acceptPeginTxid


```solidity
mapping(bytes32 acceptPeginTxid => int256 blockNumber) internal cancelUserTakeTxBlockNumber;
```


### operatorTakeInfo

```solidity
mapping(bytes32 acceptPeginTxid => OperatorTakeInfo info) internal operatorTakeInfo;
```


## Functions
### initialize

Initializes the OperatorTakeManager contract


```solidity
function initialize(
    address _initialOwner,
    address _accessManager,
    ICommitteeRegistry _committeeRegistry,
    IBitcoinManager _bitcoinManager,
    IRbtcBridge _rbtcBridge,
    IPegoutManager _pegoutManager,
    IStreamManager _streamManager,
    ISignatureManager _signatureManager,
    TakeTimeout[] memory _takeTimeouts
) public virtual initializer;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_initialOwner`|`address`|The initial owner of the contract|
|`_accessManager`|`address`|The access manager contract address|
|`_committeeRegistry`|`ICommitteeRegistry`|The committee registry contract address|
|`_bitcoinManager`|`IBitcoinManager`|The Bitcoin manager contract address|
|`_rbtcBridge`|`IRbtcBridge`|The rbtc bridge contract address for verifying Bitcoin transaction confirmations|
|`_pegoutManager`|`IPegoutManager`|The pegout manager contract address|
|`_streamManager`|`IStreamManager`|The stream manager contract address|
|`_signatureManager`|`ISignatureManager`|The signature manager contract address|
|`_takeTimeouts`|`TakeTimeout[]`|Per-stream timeout settings indexed by stream ID|


### _setTakeTimeouts


```solidity
function _setTakeTimeouts(TakeTimeout[] memory _settings) internal;
```

### setTakeTimeout

Sets the timeout settings for a specific stream

*Only callable by the contract owner*


```solidity
function setTakeTimeout(uint64 _streamId, TakeTimeout memory _timeout) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_streamId`|`uint64`|The stream identifier|
|`_timeout`|`TakeTimeout`|The new timeout settings|


### _setTakeTimeout


```solidity
function _setTakeTimeout(uint64 _streamId, TakeTimeout memory _timeout) internal;
```

### getOperatorTakeInfo

Gets temporary operator take information for a peg-out


```solidity
function getOperatorTakeInfo(bytes32 _acceptPeginTxid) external view returns (OperatorTakeInfo memory);
```

### registerCancelUserTake

Registers the cancel user take proof submitted by the operator

*Validates the SPV proof*


```solidity
function registerCancelUserTake(BtcTxSPVProof calldata _cancelUserTakeSPVProof) external nonReentrant whenNotPaused;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_cancelUserTakeSPVProof`|`BtcTxSPVProof`|The BTC SPV proof of the cancel user take transaction|


### getCancelUserTakeTxBlockNumber

Returns the bitcoin block number where the cancel user take tx was mined


```solidity
function getCancelUserTakeTxBlockNumber(bytes32 _acceptPeginTxid) external view returns (int256 blockNumber);
```

### triggerOperatorTake

Triggers the operator take process for a peg-out when not all committee members sign within timeout


```solidity
function triggerOperatorTake(bytes32 _acceptPeginTxid) external nonReentrant whenNotPaused;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_acceptPeginTxid`|`bytes32`|The accept peg-in transaction id for the peg-out|


### _handleUserTake


```solidity
function _handleUserTake(bytes32 _acceptPeginTxid, uint256 _pegoutCreatedAt, uint64 _streamId) internal;
```

### _verifyOperatorTakeTimeoutExpired


```solidity
function _verifyOperatorTakeTimeoutExpired(uint256 _operatorTakeUpdatedAt, uint64 _streamId) internal view;
```

### _updateOperatorTakeInfo


```solidity
function _updateOperatorTakeInfo(
    OperatorTakeInfo storage _opInfo,
    StreamPosition memory _streamInfo,
    address _operatorTakeAddress,
    CompactPubKey memory _operatorDisputePubKey,
    CompactPubKey memory _operatorTakePubKey
) internal;
```

### _generatePegoutId


```solidity
function _generatePegoutId(
    StreamPosition memory _streamInfo,
    CompactPubKey memory _operatorTakePubKey,
    uint256 _sequenceNumber
) internal view returns (bytes32);
```

### registerAdvanceFunds

Registers the advance funds transaction submitted by the operator

*Validates the SPV proof and updates the peg-out status accordingly*


```solidity
function registerAdvanceFunds(bytes32 _acceptPeginTxid, BtcTxSPVProof calldata _advanceFunds)
    external
    nonReentrant
    whenNotPaused;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_acceptPeginTxid`|`bytes32`|The accept peg-in transaction id that it's being advanced|
|`_advanceFunds`|`BtcTxSPVProof`|The BTC SPV proof of the advance funds transaction|


### _verifyAdvanceFundsTx


```solidity
function _verifyAdvanceFundsTx(
    BtcTxSPVProof calldata _advanceFunds,
    bytes memory _userPubKey,
    bytes32 _pegoutId,
    uint64 _streamId
) internal view returns (bytes32 txid, int256 blockNumber);
```

### registerReimbursementKickoff

Registers the reimbursement kickoff transaction submitted by the operator

*Validates the SPV proof and updates the peg-out status accordingly*


```solidity
function registerReimbursementKickoff(bytes32 _acceptPeginTxid, BtcTxSPVProof calldata _kickoffSPV)
    external
    nonReentrant
    whenNotPaused;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_acceptPeginTxid`|`bytes32`|The accept peg-in transaction id that it's being reimbursed|
|`_kickoffSPV`|`BtcTxSPVProof`|The BTC SPV proof of the reimbursement kickoff transaction|


### registerOperatorTake

Deposits an operator take proof for a peg-out transaction

*Validates the SPV proof and marks the slot as paid when operator takes over*


```solidity
function registerOperatorTake(BtcTxSPVProof calldata _pegoutTxSPVProof) external nonReentrant whenNotPaused;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_pegoutTxSPVProof`|`BtcTxSPVProof`|The BTC SPV proof of the peg-out transaction|


### registerOperatorWon

Deposits an operator won proof for a peg-out transaction

*Validates the SPV proof and marks the slot as paid when operator takes over*


```solidity
function registerOperatorWon(BtcTxSPVProof calldata _pegoutTxSPVProof) external nonReentrant whenNotPaused;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_pegoutTxSPVProof`|`BtcTxSPVProof`|The BTC SPV proof of the operator won transaction|


### _verifyConfirmationsEmitAndComplete


```solidity
function _verifyConfirmationsEmitAndComplete(
    StreamPosition memory _streamInfo,
    bytes32 _acceptPeginTxid,
    bytes32 _txid,
    bytes32 _blockHash,
    uint256 _merkleBranchPath,
    bytes32[] memory _merkleBranchHashes,
    uint128 _committeeId,
    uint8 _pegoutConfirmations
) internal;
```

### _verifyPegoutConfirmations


```solidity
function _verifyPegoutConfirmations(
    uint8 _pegoutConfirmations,
    bytes32 _txid,
    bytes32 _blockHash,
    uint256 _merkleBranchPath,
    bytes32[] memory _merkleBranchHashes
) internal view;
```

### _parseOperatorPegoutInputs


```solidity
function _parseOperatorPegoutInputs(BtcTxIn[] calldata _inputs, PegStatus _expectedStatus)
    internal
    view
    returns (
        bytes32 acceptPeginTxid,
        StreamPosition memory streamInfo,
        uint128 committeeId,
        uint8 pegoutConfirmations,
        OperatorTakeInfo storage opInfo
    );
```

### _validateOperatorTakeCaller


```solidity
function _validateOperatorTakeCaller(bytes32 _acceptPeginTxid)
    internal
    view
    returns (OperatorTakeInfo storage opInfo);
```

### _getOperatorTakeData


```solidity
function _getOperatorTakeData(bytes32 _acceptPeginTxid, address _opAddress)
    internal
    view
    returns (OperatorTakeData memory);
```

