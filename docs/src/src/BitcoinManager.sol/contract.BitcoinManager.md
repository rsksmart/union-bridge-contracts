# BitcoinManager
[Git Source](https://github.com/temp-rsk/bitvmx-union-bridge-contracts/blob/13960dd321557c932048de4fc7353af5ceae0b8d/src/BitcoinManager.sol)

**Inherits:**
[IBitcoinManager](/src/interfaces/IBitcoinManager.sol/interface.IBitcoinManager.md), Initializable, [BaseProxy](/src/BaseProxy.sol/abstract.BaseProxy.md)

Manages Bitcoin addresses and scripts for the union bridge

*Provides functionality for creating and validating Bitcoin transactions, addresses, and scripts*

*Handles peg-in requests, peg-in acceptance, speed-up transactions, and peg-out operations*


## State Variables
### network
The Bitcoin network this contract operates on (mainnet, testnet, or regtest)

*Determines the address format and network-specific parameters*


```solidity
BtcNetwork public network;
```


### peginManager
Peg manager contract for peg-in/peg-out coordination


```solidity
IPeginManager peginManager;
```


## Functions
### initialize

Initializes the BitcoinManager contract

*Sets up the Bitcoin network and initial owner*

*Can only be called once during contract deployment*


```solidity
function initialize(address _initialOwner, BtcNetwork _network) public initializer;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_initialOwner`|`address`|The address that will be set as the initial owner|
|`_network`|`BtcNetwork`|The Bitcoin network to operate on|


### setPeginManager

Sets the Peg Manager contract address

*Only callable by the contract owner*


```solidity
function setPeginManager(IPeginManager _peginManager) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_peginManager`|`IPeginManager`|The address of the Pegin Manager contract|


### getBtcTxid

Converts a Bitcoin transaction to raw hex format and calculates its hash

*Uses Bitcoin format encoding and then applies hash256 to get the transaction id*


```solidity
function getBtcTxid(BtcTransaction calldata _btcTx) external pure returns (bytes32);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_btcTx`|`BtcTransaction`|The Bitcoin transaction to hash|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|The transaction id in bytes32 format|


### _getBtcTxid


```solidity
function _getBtcTxid(BtcTransaction memory _btcTx) internal pure returns (bytes32);
```

### getTemporaryPeginAddress

Generates a temporary peg-in address for a peg-in request

*Creates a Taproot address with both key spend and script spend paths*


```solidity
function getTemporaryPeginAddress(
    address _rskDestinationAddress,
    uint64 _value,
    bytes32 _btcReimbursementPubKey,
    bytes memory _committeePubKey
) external view returns (string memory temporaryPeginAddress);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_rskDestinationAddress`|`address`|The RSK address that will receive the RBTC|
|`_value`|`uint64`|The amount in satoshis for the peg-in request|
|`_btcReimbursementPubKey`|`bytes32`|The user's Bitcoin public key for reimbursement (x-only)|
|`_committeePubKey`|`bytes`|The committee's public key for the Taproot address|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`temporaryPeginAddress`|`string`|The generated temporary Bitcoin address for deposit|


### getRequestPeginTweakedPublicKey

*Generates the RequestPegin Taproot output script pub key with both key spend and script spend paths*


```solidity
function getRequestPeginTweakedPublicKey(
    address _rskDestinationAddress,
    uint64 _value,
    bytes32 _btcReimbursementPubKey,
    bytes memory _committeePubKey
) internal pure returns (bytes32);
```

### _validateRequestPeginInputs

*Validates the inputs for a peg-in request*


```solidity
function _validateRequestPeginInputs(
    bytes32 _btcReimbursementPubKey,
    bytes memory _committeePubKey,
    address _rskDestinationAddress,
    uint64 _value
) internal pure;
```

### getPeginOpReturnData

Extracts data from a peg-in OP_RETURN output

*Expected OP_RETURN format:*

*[OP_RETURN (1 byte)]*

*[OP_PUSHBYTES_69 (1 byte)]*

*[RSK_PEGIN (9 bytes)]*

*[packet number (8 bytes)]*

*[rsk destination address (20 bytes)]*

*[reimbursement public key (32 bytes)]*

*Total expected size: 71 bytes*


```solidity
function getPeginOpReturnData(BtcTxOut calldata _opReturnOut) external pure returns (uint64, address, bytes32);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_opReturnOut`|`BtcTxOut`|The OP_RETURN output to parse|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint64`|The packet number, RSK destination address, and Bitcoin reimbursement public key|
|`<none>`|`address`||
|`<none>`|`bytes32`||


### validateRequestPeginP2TROutput

Validates output against a Taproot script with both key spend and script spend paths


```solidity
function validateRequestPeginP2TROutput(
    address _rskDestinationAddress,
    uint64 _streamDenomination,
    bytes32 _btcReimbursementPubKey,
    bytes memory _committeePubKey,
    BtcTxOut calldata _p2trOut
) external view onlyPeginManager;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_rskDestinationAddress`|`address`|Address that will get the RBTC|
|`_streamDenomination`|`uint64`|The expected amount in satoshis|
|`_btcReimbursementPubKey`|`bytes32`|The user's public key (x-only, 32 bytes)|
|`_committeePubKey`|`bytes`|The committee's public key (x-only, 32 bytes)|
|`_p2trOut`|`BtcTxOut`|The P2TR output of the peg-in request|


### getRequestPeginP2TRScriptPub

Generates the RequestPegin Taproot output script pub key with both key spend and script spend paths


```solidity
function getRequestPeginP2TRScriptPub(
    address _rskDestinationAddress,
    uint64 _value,
    bytes32 _btcReimbursementPubKey,
    bytes memory _committeePubKey
) internal pure returns (bytes memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_rskDestinationAddress`|`address`|The RSK address that will receive the RBTC|
|`_value`|`uint64`|The amount in satoshis for the peg-in request|
|`_btcReimbursementPubKey`|`bytes32`|The user's Bitcoin public key for reimbursement (x-only)|
|`_committeePubKey`|`bytes`|The committee's public key for the Taproot address (x-only)|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes`|The P2TR script pub key bytes|


### _compareOutputPubKey


```solidity
function _compareOutputPubKey(bytes memory outputPubKey, bytes memory expectedPubKey) internal pure;
```

### validatePegoutUserOutput

Validates a peg-out user output against the expected P2WPKH script


```solidity
function validatePegoutUserOutput(BtcTxOut calldata _userOutput, bytes memory _userPubKey) external pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_userOutput`|`BtcTxOut`|The Bitcoin transaction output to validate|
|`_userPubKey`|`bytes`|The user's public key to generate the expected script|


### validatePegoutMemberOutput


```solidity
function validatePegoutMemberOutput(BtcTxOut calldata _userOutput, bytes32 _memberPubKey) external pure;
```

### getAcceptPeginSignatureHash

Gets the signature hash for a peg-in accept transaction


```solidity
function getAcceptPeginSignatureHash(
    bytes memory _committeePubKey,
    bytes32 _userXOnlyPubKey,
    bytes32 _registerPeginTx,
    PrevoutData memory _prevoutData
) external view onlyPeginManager returns (BitcoinSignatureData memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_committeePubKey`|`bytes`|The committee's public key (x-only)|
|`_userXOnlyPubKey`|`bytes32`|The user's public key (x-only) for speed-up output|
|`_registerPeginTx`|`bytes32`|The hash of the register peg-in transaction|
|`_prevoutData`|`PrevoutData`|The previous output data for the input|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`BitcoinSignatureData`|The transaction id, signature hash, and signature message|


### getAcceptPeginTweakedPublicKey

*Generates the Accept Pegin Taproot output script pub key with both key spend and script spend paths*


```solidity
function getAcceptPeginTweakedPublicKey(bytes memory _committeePubKey) internal pure returns (bytes32);
```

### getAcceptPeginP2TRScriptPub

Generates the Accept Pegin Taproot output script pub key with both key spend and script spend paths


```solidity
function getAcceptPeginP2TRScriptPub(bytes memory _committeePubKey) internal pure returns (bytes memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_committeePubKey`|`bytes`|The committee's public key (x-only)|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes`|The P2TR script pub key bytes|


### validateSpeedUpOutput

Validates the speed-up output


```solidity
function validateSpeedUpOutput(bytes32 _pubKey, BtcTxOut calldata _speedUpOut) external pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_pubKey`|`bytes32`|The public key for the speed-up output (x-only)|
|`_speedUpOut`|`BtcTxOut`|The speed-up output to validate|


### getSpeedUpScriptPub

Generates the speed-up script pub key


```solidity
function getSpeedUpScriptPub(bytes32 _pubKey) public pure returns (bytes memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_pubKey`|`bytes32`|The public key for the speed-up output (x-only)|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes`|The P2WPKH script pub key bytes|


### getPegoutTxData

Generates the signature hash for a peg-out transaction


```solidity
function getPegoutTxData(bytes memory _userPubKey, bytes32 _acceptPeginTx, PrevoutData memory _prevoutData)
    external
    pure
    returns (BitcoinSignatureData memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_userPubKey`|`bytes`|The user's public key for the peg-out|
|`_acceptPeginTx`|`bytes32`|The hash of the accept peg-in transaction|
|`_prevoutData`|`PrevoutData`|The previous output data for the input|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`BitcoinSignatureData`|bytes32 The txid, bytes32 the signature hash and bytes signature message|


### taprootSignatureHash

*Returns Signature Hash. The signature hash is the actual "message" that we sign when creating the signature.*

*It's a tagged hash of the common signature message, along with a sighash epoch prefix and the optional extension:*

*https://learnmeabitcoin.com/technical/upgrades/taproot/#signature-hash*


```solidity
function taprootSignatureHash(uint8 _hashType, PrevoutData[] memory _prevoutDatas, BtcTransaction memory _btcTx)
    internal
    pure
    returns (bytes32, bytes memory);
```

### onlyPeginManager

Modifier to restrict access to the PeginManager contract


```solidity
modifier onlyPeginManager();
```

### _onlyPeginManager


```solidity
function _onlyPeginManager(address _account) internal view;
```

