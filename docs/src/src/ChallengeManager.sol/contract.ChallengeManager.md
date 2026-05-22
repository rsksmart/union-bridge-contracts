# ChallengeManager
[Git Source](https://github.com/rsksmart/union-bridge-contracts/blob/dd34207db3c68e4260aba3e2d2660c73733e6970/src/ChallengeManager.sol)

**Inherits:**
[IChallengeManager](/src/interfaces/IChallengeManager.sol/interface.IChallengeManager.md), [PegBase](/src/PegBase.sol/abstract.PegBase.md)

Manages challenge operations


## State Variables
### operatorTakeManager
The PegoutManager contract


```solidity
IOperatorTakeManager public operatorTakeManager;
```


### challengeInfo
Information stored during challenge processing

*Contains data needed for challenge transaction validation*


```solidity
mapping(bytes32 acceptPeginTxid => ChallengeInfo info) internal challengeInfo;
```


## Functions
### getChallengeInfo

Gets the challenge information for a given accept peg-in transaction id


```solidity
function getChallengeInfo(bytes32 _acceptPeginTxid) external view returns (ChallengeInfo memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_acceptPeginTxid`|`bytes32`|The accept peg-in transaction id|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`ChallengeInfo`|The challenge information|


### initialize

Initializes the ChallengeManager contract


```solidity
function initialize(
    address _initialOwner,
    address _accessManager,
    ICommitteeRegistry _committeeRegistry,
    IBitcoinManager _bitcoinManager,
    IRbtcBridge _rbtcBridge,
    IStreamManager _streamManager,
    IOperatorTakeManager _operatorTakeManager
) public initializer;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_initialOwner`|`address`|The initial owner of the contract|
|`_accessManager`|`address`|The access manager contract address|
|`_committeeRegistry`|`ICommitteeRegistry`|The committee registry contract address|
|`_bitcoinManager`|`IBitcoinManager`|The Bitcoin manager contract address|
|`_rbtcBridge`|`IRbtcBridge`|The rbtc bridge contract address for verifying Bitcoin transaction confirmations|
|`_streamManager`|`IStreamManager`|The stream manager contract address|
|`_operatorTakeManager`|`IOperatorTakeManager`||


### registerChallenge

Registers a challenge for a peg-out transaction

*Validates the SPV proof and updates the peg-out status accordingly*


```solidity
function registerChallenge(bytes32 _acceptPeginTxid, BtcTxSPVProof calldata _challenge)
    external
    nonReentrant
    whenNotPaused;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_acceptPeginTxid`|`bytes32`|The accept peg-in transaction id that is being challenged|
|`_challenge`|`BtcTxSPVProof`|The BTC SPV proof of the challenge transaction|


### _getChallengeInfo


```solidity
function _getChallengeInfo(bytes32 _acceptPeginTxid) internal view returns (ChallengeInfo storage);
```

### registerInputNotRevealed

Registers an input not revealed for a challenge transaction

*Validates the SPV proof and updates the challenge status accordingly*


```solidity
function registerInputNotRevealed(bytes32 _acceptPeginTxid, BtcTxSPVProof calldata _inputNotRevealed)
    external
    nonReentrant
    whenNotPaused;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_acceptPeginTxid`|`bytes32`|The accept peg-in transaction id that is being challenged|
|`_inputNotRevealed`|`BtcTxSPVProof`|The BTC SPV proof of the input not revealed transaction|


### registerInputRevealed

Registers an input revealed for a challenge transaction

*Validates the SPV proof and updates the challenge status accordingly*


```solidity
function registerInputRevealed(bytes32 _acceptPeginTxid, BtcTxSPVProof memory _inputRevealed)
    external
    nonReentrant
    whenNotPaused;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_acceptPeginTxid`|`bytes32`|The accept peg-in transaction id that is being challenged|
|`_inputRevealed`|`BtcTxSPVProof`|The BTC SPV proof of the input revealed transaction|


### registerStopOperatorWon

Registers a stop operator won for a reveal transaction

*Validates the SPV proof and updates the challenge status accordingly*


```solidity
function registerStopOperatorWon(bytes32 _acceptPeginTxid, BtcTxSPVProof calldata _stopOperatorWon)
    external
    nonReentrant
    whenNotPaused;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_acceptPeginTxid`|`bytes32`|The accept peg-in transaction id that is being challenged|
|`_stopOperatorWon`|`BtcTxSPVProof`|The BTC SPV proof of the stop operator won transaction|


