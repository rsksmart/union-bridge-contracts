# ChallengeManager
[Git Source](https://github.com/rsksmart/union-bridge-contracts/blob/b56fdca4d854a3d344854107131d121e04834d63/src/ChallengeManager.sol)

**Inherits:**
[IChallengeManager](/src/interfaces/IChallengeManager.sol/interface.IChallengeManager.md), [PegBase](/src/PegBase.sol/abstract.PegBase.md)

Manages challenge operations


## State Variables
### pegoutManager
The PegoutManager contract


```solidity
IPegoutManager public pegoutManager;
```


### challengeTempInfo
Temporary information stored during challenge processing

*Contains data needed for challenge transaction validation*


```solidity
mapping(bytes32 acceptPeginTxid => ChallengeTempInfo tempInfo) internal challengeTempInfo;
```


## Functions
### getChallengeTempInfo

Gets the temporary challenge information for a given accept peg-in transaction id


```solidity
function getChallengeTempInfo(bytes32 _acceptPeginTxid) external view returns (ChallengeTempInfo memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_acceptPeginTxid`|`bytes32`|The accept peg-in transaction id|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`ChallengeTempInfo`|The temporary challenge information|


### initialize

Initializes the ChallengeManager contract


```solidity
function initialize(
    address _initialOwner,
    address _accessManager,
    ICommitteeRegistry _committeeRegistry,
    IBitcoinManager _bitcoinManager,
    IRbtcBridge _rbtcBridge,
    IPegoutManager _pegoutManager,
    IStreamManager _streamManager
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
|`_pegoutManager`|`IPegoutManager`|The pegout manager contract address|
|`_streamManager`|`IStreamManager`|The stream manager contract address|


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


### _validateMemberInCommittee


```solidity
function _validateMemberInCommittee(uint128 _committeeId) internal view;
```

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
|`_acceptPeginTxid`|`bytes32`|The accept peg-in transaction id that is being revealed|
|`_inputRevealed`|`BtcTxSPVProof`|The BTC SPV proof of the input revealed transaction|


