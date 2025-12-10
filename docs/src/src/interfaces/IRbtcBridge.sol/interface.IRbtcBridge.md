# IRbtcBridge
[Git Source](https://github.com/temp-rsk/bitvmx-union-bridge-contracts/blob/4c35e62294ee16f56ba26d52283a5d84868fbd84/src/interfaces/IRbtcBridge.sol)

Interface for the RbtcBridge contract that acts as the single authorized intermediary
between the Union Bridge system and the RSK PowPeg Bridge for RBTC minting/burning operations

*This contract is required because RSKIP-502 only allows ONE contract address to be authorized
for minting and burning RBTC from the PowPeg bridge. Since PegManager is split into
PeginManager and PegoutManager, we need this intermediary to be the single authorized address.*


## Functions
### initialize

Initializes the RbtcBridge contract


```solidity
function initialize(address _initialOwner, address _bridge) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_initialOwner`|`address`|The initial owner of the contract|
|`_bridge`|`address`|The RSK PowPeg Bridge contract address|


### setPeginManager

Sets the PeginManager contract address

*Only callable by owner*


```solidity
function setPeginManager(address _peginManager) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_peginManager`|`address`|The PeginManager contract address|


### setPegoutManager

Sets the PegoutManager contract address

*Only callable by owner*


```solidity
function setPegoutManager(address _pegoutManager) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_pegoutManager`|`address`|The PegoutManager contract address|


### mintRbtc

Mints RBTC from the PowPeg bridge and sends it to the specified address

*Only callable by the peginManager*

*Requests RBTC from PowPeg bridge via requestUnionBridgeRbtc*

*Transfers RBTC to recipient with 100k gas limit*


```solidity
function mintRbtc(address payable _to, uint256 _amount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_to`|`address payable`|The address to receive the minted RBTC|
|`_amount`|`uint256`|The amount of RBTC to mint in wei|


### burnRbtc

Burns RBTC back to the PowPeg bridge

*Only callable by the pegoutManager*

*The pegoutManager must send the RBTC amount via msg.value*

*Returns RBTC to PowPeg bridge via releaseUnionBridgeRbtc*


```solidity
function burnRbtc() external payable;
```

## Events
### RbtcMinted
Emitted when RBTC is minted and sent to a user


```solidity
event RbtcMinted(address indexed to, uint256 amount);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`to`|`address`|The address that received the RBTC|
|`amount`|`uint256`|The amount of RBTC minted in wei|

### RbtcBurned
Emitted when RBTC is burned back to the PowPeg bridge


```solidity
event RbtcBurned(uint256 amount);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|The amount of RBTC burned in wei|

## Errors
### UnauthorizedCaller
Thrown when an unauthorized address attempts to call a restricted function


```solidity
error UnauthorizedCaller(address caller);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`caller`|`address`|The address that attempted the unauthorized call|

### FailedToSendRBTC
Thrown when RBTC transfer to recipient fails


```solidity
error FailedToSendRBTC(address to, uint256 amount);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`to`|`address`|The intended recipient address|
|`amount`|`uint256`|The amount that failed to transfer|

### BridgeUnauthorizedCaller
Thrown when the PowPeg bridge rejects the request due to unauthorized caller (error code -1)


```solidity
error BridgeUnauthorizedCaller();
```

### BridgeExceededLockingCap
Thrown when the requested amount exceeds the PowPeg bridge locking cap (error code -2)


```solidity
error BridgeExceededLockingCap(uint256 amount);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|The amount that exceeded the cap|

### BridgeTransfersDisabled
Thrown when RBTC transfers are currently disabled in the PowPeg bridge (error code -3)


```solidity
error BridgeTransfersDisabled();
```

### BridgeReleaseInvalidValue
Thrown when the burn amount exceeds the previously minted amount (error code -2)


```solidity
error BridgeReleaseInvalidValue(uint256 amount);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|The invalid burn amount|

### BridgeBtcUnknownError
Thrown when the PowPeg bridge returns an unknown error code


```solidity
error BridgeBtcUnknownError(int256 errorCode);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`errorCode`|`int256`|The error code returned by the bridge|

### BridgeAddressZero
Thrown when the bridge address is set to zero during initialization


```solidity
error BridgeAddressZero();
```

### PeginManagerAddressZero
Thrown when the peginManager address is set to zero during initialization


```solidity
error PeginManagerAddressZero();
```

### PegoutManagerAddressZero
Thrown when the pegoutManager address is set to zero during initialization


```solidity
error PegoutManagerAddressZero();
```

