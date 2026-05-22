# RbtcBridge
[Git Source](https://github.com/temp-rsk/bitvmx-union-bridge-contracts/blob/bd6b4a28bf5973e554d9b7a237190a44cdd46b38/src/RbtcBridge.sol)

**Inherits:**
[IRbtcBridge](/src/interfaces/IRbtcBridge.sol/interface.IRbtcBridge.md), ReentrancyGuardUpgradeable, [BaseProxy](/src/BaseProxy.sol/abstract.BaseProxy.md), [Pausable](/src/Pausable.sol/abstract.Pausable.md)

Intermediary contract that acts as the single authorized address for RBTC minting/burning
with the RSK PowPeg Bridge, serving both PeginManager and PegoutManager

*This contract is necessary because RSKIP-502 only allows ONE contract address to be authorized
for minting and burning RBTC. Since PegManager was split into PeginManager and PegoutManager,
this bridge serves as the single authorized intermediary.*

*Implements RSKIP-502: https://github.com/rsksmart/RSKIPs/blob/master/IPs/RSKIP502.md*


## State Variables
### bridge
The RSK Bridge contract used for Bitcoin transaction verification

*This contract provides access to Bitcoin transaction confirmation data*


```solidity
IBridge public bridge;
```


### accessManager
The access manager contract that manages access control

*Used to check access control for sensitive operations*


```solidity
IAccessManager public accessManager;
```


## Functions
### initialize

Initializes the RbtcBridge contract


```solidity
function initialize(address _initialOwner, IBridge _bridge, IAccessManager _accessManager) external initializer;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_initialOwner`|`address`|The initial owner of the contract|
|`_bridge`|`IBridge`|The RSK PowPeg Bridge contract address|
|`_accessManager`|`IAccessManager`|The access manager contract address|


### receive

Allows the contract to receive RBTC from the PowPeg bridge

*This function is called when the PowPeg bridge mints RBTC to this contract*


```solidity
receive() external payable;
```

### mintRbtc

Mints RBTC from the PowPeg bridge and sends it to the specified address

*Only callable by the peginManager when contract is not paused*


```solidity
function mintRbtc(address payable _to, uint256 _amount) external nonReentrant whenNotPaused;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_to`|`address payable`|The address to receive the minted RBTC|
|`_amount`|`uint256`|The amount of RBTC to mint in wei|


### burnRbtc

Burns RBTC back to the PowPeg bridge

*Only callable by the pegoutManager when contract is not paused*


```solidity
function burnRbtc() external payable nonReentrant whenNotPaused;
```

### _mintRbtc

Internal function to mint RBTC from the PowPeg bridge and send to recipient

*Requests RBTC from PowPeg bridge via RSKIP-502 requestUnionBridgeRbtc*

*Then transfers the RBTC to the recipient with a 100k gas limit*


```solidity
function _mintRbtc(address payable _to, uint256 _amount) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_to`|`address payable`|The address to receive the RBTC|
|`_amount`|`uint256`|The amount of RBTC to mint in wei|


### _sendRbtc

Internal function to send RBTC to a recipient with a gas limit

*Uses a 100k gas limit to prevent DoS attacks while allowing some DeFi operations*

*Gas limit prevents malicious receive() functions from consuming all gas*


```solidity
function _sendRbtc(address payable _to, uint256 _amount) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_to`|`address payable`|The address to send RBTC to|
|`_amount`|`uint256`|The amount of RBTC to send in wei|


### _releaseRbtc

Internal function to release RBTC back to the PowPeg bridge

*Burns RBTC back to PowPeg bridge via RSKIP-502 releaseUnionBridgeRbtc*


```solidity
function _releaseRbtc(uint256 _amountToReturn) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_amountToReturn`|`uint256`|The amount of RBTC to return to the bridge in wei|


### getUnionBridgeLockingCap

Gets the locking cap of the Union Bridge for RBTC minting operations


```solidity
function getUnionBridgeLockingCap() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|unionBridgeLockingCap The locking cap of the Union Bridge|


### verifyTxConfirmations

Verifies that a Bitcoin transaction exists in a block and has enough confirmations

*Uses RSK bridge precompiled contract to verify the transaction*


```solidity
function verifyTxConfirmations(
    uint256 _minConfirmations,
    bytes32 _txid,
    bytes32 _blockHash,
    uint256 _merkleBranchPath,
    bytes32[] memory _merkleBranchHashes
) external view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_minConfirmations`|`uint256`|The minimum number of confirmations required for the transaction|
|`_txid`|`bytes32`|The hash of the Bitcoin transaction to verify|
|`_blockHash`|`bytes32`|The hash of the block containing the transaction|
|`_merkleBranchPath`|`uint256`|The path in the merkle tree to verify the transaction|
|`_merkleBranchHashes`|`bytes32[]`|The hashes needed to verify the merkle proof|


### _verifyTxConfirmations


```solidity
function _verifyTxConfirmations(
    uint256 _minConfirmations,
    bytes32 _txid,
    bytes32 _blockHash,
    uint256 _merkleBranchPath,
    bytes32[] memory _merkleBranchHashes
) internal view returns (int256);
```

### getTxBlockNumberAndVerifyConfirmations

Verifies that a Bitcoin transaction exists in a block and has enough confirmations

*Uses RSK bridge precompiled contract to verify the transaction*


```solidity
function getTxBlockNumberAndVerifyConfirmations(
    uint256 _minConfirmations,
    bytes32 _txid,
    bytes32 _blockHash,
    uint256 _merkleBranchPath,
    bytes32[] memory _merkleBranchHashes
) external view returns (int256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_minConfirmations`|`uint256`|The minimum number of confirmations required for the transaction|
|`_txid`|`bytes32`|The hash of the Bitcoin transaction to verify|
|`_blockHash`|`bytes32`|The hash of the block containing the transaction|
|`_merkleBranchPath`|`uint256`|The path in the merkle tree to verify the transaction|
|`_merkleBranchHashes`|`bytes32[]`|The hashes needed to verify the merkle proof|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`int256`|blockNumber The block number of the transaction|


### getBestBlockHash

Gets the hash of the best block in the Bitcoin blockchain


```solidity
function getBestBlockHash() external view returns (bytes32);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|bestBlockHash The hash of the best block in the Bitcoin blockchain|


### setBaseEvent

Sets the base event

*This function will revert if:*


```solidity
function setBaseEvent(bytes memory _baseEvent) external nonReentrant whenNotPaused;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_baseEvent`|`bytes`|The new base event (must be less than 128 bytes)|


