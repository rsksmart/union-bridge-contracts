# RbtcBridge
[Git Source](https://github.com/temp-rsk/bitvmx-union-bridge-contracts/blob/4c35e62294ee16f56ba26d52283a5d84868fbd84/src/RbtcBridge.sol)

**Inherits:**
[IRbtcBridge](/src/interfaces/IRbtcBridge.sol/interface.IRbtcBridge.md), [BaseProxy](/src/BaseProxy.sol/abstract.BaseProxy.md), ReentrancyGuardUpgradeable

Intermediary contract that acts as the single authorized address for RBTC minting/burning
with the RSK PowPeg Bridge, serving both PeginManager and PegoutManager

*This contract is necessary because RSKIP-502 only allows ONE contract address to be authorized
for minting and burning RBTC. Since PegManager was split into PeginManager and PegoutManager,
this bridge serves as the single authorized intermediary.*

*Implements RSKIP-502: https://github.com/rsksmart/RSKIPs/blob/master/IPs/RSKIP502.md*


## State Variables
### bridge
The RSK PowPeg Bridge contract


```solidity
IBridge public bridge;
```


### peginManager
The PeginManager contract address (authorized to mint RBTC)


```solidity
address public peginManager;
```


### pegoutManager
The PegoutManager contract address (authorized to burn RBTC)


```solidity
address public pegoutManager;
```


## Functions
### constructor

**Note:**
oz-upgrades-unsafe-allow: constructor


```solidity
constructor();
```

### initialize

Initializes the RbtcBridge contract

*Manager addresses must be set after initialization via setPeginManager/setPegoutManager*


```solidity
function initialize(address _initialOwner, address _bridge) external initializer;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_initialOwner`|`address`|The initial owner of the contract|
|`_bridge`|`address`|The RSK PowPeg Bridge contract address|


### receive

Allows the contract to receive RBTC from the PowPeg bridge

*This function is called when the PowPeg bridge mints RBTC to this contract*


```solidity
receive() external payable;
```

### setPeginManager

Sets the PeginManager contract address

*Only callable by owner*


```solidity
function setPeginManager(address _peginManager) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_peginManager`|`address`|The PeginManager contract address|


### setPegoutManager

Sets the PegoutManager contract address

*Only callable by owner*


```solidity
function setPegoutManager(address _pegoutManager) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_pegoutManager`|`address`|The PegoutManager contract address|


### mintRbtc

Mints RBTC from the PowPeg bridge and sends it to the specified address

*Only callable by peginManager*

*Follows checks-effects-interactions pattern*


```solidity
function mintRbtc(address payable _to, uint256 _amount) external nonReentrant;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_to`|`address payable`|The address to receive the minted RBTC|
|`_amount`|`uint256`|The amount of RBTC to mint in wei|


### burnRbtc

Burns RBTC back to the PowPeg bridge

*Only callable by pegoutManager*

*The pegoutManager must send the RBTC amount via msg.value*


```solidity
function burnRbtc() external payable nonReentrant;
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


