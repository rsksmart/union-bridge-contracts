# BitcoinManager
[Git Source](https://github.com/rsksmart/union-bridge-contracts/blob/68c14faa89612dfba1b7e9abf29455625661476f/src/BitcoinManager.sol)

**Inherits:**
[IBitcoinManager](/src/interfaces/IBitcoinManager.sol/interface.IBitcoinManager.md), [BaseProxy](/src/BaseProxy.sol/abstract.BaseProxy.md)

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


### getBtcTxid

Calculates the Bitcoin transaction id (txid) for a given transaction

*Encodes the transaction into Bitcoin's raw format and performs double SHA256 hash*


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
|`<none>`|`bytes32`|txid The transaction id in big-endian format (standard hex representation)|


### _getBtcTxid


```solidity
function _getBtcTxid(BtcTransaction memory _btcTx) internal pure returns (bytes32);
```

### getTemporaryPeginAddress

Obtains a temporary Bitcoin address for request peg-in operations

*Creates a Taproot address with committee and user key paths for secure peg-in*


```solidity
function getTemporaryPeginAddress(
    uint32 _timelockBlocks,
    address _rskDestinationAddress,
    uint64 _value,
    bytes32 _btcReimbursementPubKey,
    bytes memory _committeePubKey
) external view returns (string memory temporaryPeginAddress);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_timelockBlocks`|`uint32`|The timelock blocks for the Bitcoin transaction|
|`_rskDestinationAddress`|`address`|The RSK address that will receive the RBTC|
|`_value`|`uint64`|The amount in satoshis to peg in (must match stream denomination)|
|`_btcReimbursementPubKey`|`bytes32`|The user's Bitcoin public key (x-coordinate only, 32 bytes)|
|`_committeePubKey`|`bytes`|The committee's public key|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`temporaryPeginAddress`|`string`|The generated temporary Bitcoin address for deposit|


### _getRequestPeginTweakedPublicKey

*Generates the RequestPegin Taproot output script pub key with both key spend and script spend paths*


```solidity
function _getRequestPeginTweakedPublicKey(
    uint32 _timelockBlocks,
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
    uint32 _timelockBlocks,
    bytes32 _btcReimbursementPubKey,
    bytes memory _committeePubKey,
    address _rskDestinationAddress,
    uint64 _value
) internal pure;
```

### getPeginOpReturnData

Extracts data from a request peg-in Bitcoin transaction's OP_RETURN output

*Expected OP_RETURN format: [OP_RETURN][RSK_PEGIN][packet number][rsk destination address][btc reimbursement public key]*


```solidity
function getPeginOpReturnData(BtcTxOut calldata _opReturnOut) external pure returns (uint64, address, bytes32);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_opReturnOut`|`BtcTxOut`|The Bitcoin transaction output containing OP_RETURN data|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint64`|packetNumber The packet number encoded in the OP_RETURN data|
|`<none>`|`address`|destinationAddress The RSK destination address encoded in the OP_RETURN data|
|`<none>`|`bytes32`|btcReimbursementPubKey The Bitcoin reimbursement public key (x only) encoded in the OP_RETURN data|


### validateRequestPeginP2TROutput

Validates a P2TR output for request peg-in transactions

*Ensures the Taproot output has the correct script structure with committee and user key paths*


```solidity
function validateRequestPeginP2TROutput(
    uint32 _timelockBlocks,
    address _rskDestinationAddress,
    uint64 _streamDenomination,
    bytes32 _btcReimbursementPubKey,
    bytes memory _committeePubKey,
    BtcTxOut calldata _p2trOut
) external pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_timelockBlocks`|`uint32`|The timelock blocks for the Bitcoin transaction|
|`_rskDestinationAddress`|`address`|The RSK address that should receive the RBTC|
|`_streamDenomination`|`uint64`|The expected amount in satoshis|
|`_btcReimbursementPubKey`|`bytes32`|The user's Bitcoin public key (x-coordinate only)|
|`_committeePubKey`|`bytes`|The committee's public key|
|`_p2trOut`|`BtcTxOut`|The Bitcoin transaction output to validate|


### validateRequestPeginEnablerOutput

Validates the enabler output in a request peg-in transaction

*We don't check the inputs as this function is called by the pegin manager that already validated the inputs*


```solidity
function validateRequestPeginEnablerOutput(bytes memory _expectedEnablerScriptPubKey, BtcTxOut calldata _enablerOut)
    external
    pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_expectedEnablerScriptPubKey`|`bytes`|The expected enabler script pub key (from packet storage)|
|`_enablerOut`|`BtcTxOut`|The enabler output to validate|


### _getRequestPeginP2TRScriptPub

Generates the RequestPegin Taproot output script pub key with both key spend and script spend paths


```solidity
function _getRequestPeginP2TRScriptPub(
    uint32 _timelockBlocks,
    address _rskDestinationAddress,
    uint64 _value,
    bytes32 _btcReimbursementPubKey,
    bytes memory _committeePubKey
) internal pure returns (bytes memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_timelockBlocks`|`uint32`|The timelock blocks for the Bitcoin transaction|
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

Validates that a peg-out transaction output is a P2WPKH paying the user

*Ensures the output correctly pays the user with the expected P2WPKH script*


```solidity
function validatePegoutUserOutput(BtcTxOut calldata _pegoutOutput, bytes memory _userPubKey) external pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_pegoutOutput`|`BtcTxOut`|The Bitcoin transaction output to validate|
|`_userPubKey`|`bytes`|The user's public key that should receive the funds|


### validatePegoutMemberOutput

Validates that a peg-out transaction output is a P2WPKH paying the committee member

*Ensures the output correctly pays the committee member with the expected P2WPKH script*


```solidity
function validatePegoutMemberOutput(BtcTxOut calldata _pegoutOutput, bytes32 _memberPubKey) external pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_pegoutOutput`|`BtcTxOut`|The Bitcoin transaction output to validate|
|`_memberPubKey`|`bytes32`|The committee member's public key that should receive the funds|


### validatePegoutIdOutput

Validates that a peg-out transaction output encodes the correct peg-out id in OP_RETURN

*Ensures the OP_RETURN output contains the expected peg-out id for tracking*


```solidity
function validatePegoutIdOutput(BtcTxOut calldata _pegoutIdOutput, bytes32 _pegoutId) external pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_pegoutIdOutput`|`BtcTxOut`|The Bitcoin transaction output containing OP_RETURN data|
|`_pegoutId`|`bytes32`|The expected peg-out id to validate against|


### getAcceptPeginSignatureHash

Calculates the signature hash for Bitcoin accept peg-in transactions

*Generates the hash that committee members must sign to accept a peg-in*


```solidity
function getAcceptPeginSignatureHash(
    bytes memory _committeePubKey,
    bytes32 _userXOnlyPubKey,
    bytes32 _registerPeginTx,
    PrevoutData[] memory _prevoutDatas,
    bytes32[] memory _disputeKeys
) external pure returns (BitcoinSignatureData memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_committeePubKey`|`bytes`|The committee's public key (x-coordinate only)|
|`_userXOnlyPubKey`|`bytes32`|The user's public key (x-coordinate only, 32 bytes)|
|`_registerPeginTx`|`bytes32`|The transaction id of the peg-in request being spent|
|`_prevoutDatas`|`PrevoutData[]`|Array of prevout data for all inputs being spent (taptree + enabler outputs)|
|`_disputeKeys`|`bytes32[]`|The dispute keys (covenant public keys) for all members|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`BitcoinSignatureData`|BitcoinSignatureData containing txid, signatureHash, and signatureMessage|


### _getAcceptPeginTweakedPublicKey

*Generates the Accept Pegin Taproot output script pub key with both key spend and script spend paths*


```solidity
function _getAcceptPeginTweakedPublicKey(bytes memory _committeePubKey) internal pure returns (bytes32);
```

### _getVerifyKeyScript


```solidity
function _getVerifyKeyScript(bytes32 _disputeKey) internal pure returns (bytes memory);
```

### _getVerifyKeyLeaves


```solidity
function _getVerifyKeyLeaves(bytes32[] memory _keys) internal pure returns (bytes32[] memory);
```

### _buildMerkleTreeFromLeaves

Builds a balanced Taproot merkle tree from leaves

*Implements the same balanced tree algorithm as Bitcoin's TaprootBuilder*


```solidity
function _buildMerkleTreeFromLeaves(bytes32[] memory _leaves) internal pure returns (bytes32);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_leaves`|`bytes32[]`|Array of leaf hashes to build the tree from|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|The merkle root hash|


### _getEnablerOutputTweakedPublicKey


```solidity
function _getEnablerOutputTweakedPublicKey(bytes memory _committeePubKey, bytes32[] memory _disputeKeys)
    internal
    pure
    returns (bytes32);
```

### getEnablerOutputP2TRScriptPub

Generates the enabler output P2TR script pub key

*Creates a Taproot script for the enabler output with dispute keys in the merkle tree*


```solidity
function getEnablerOutputP2TRScriptPub(bytes memory _committeePubKey, bytes32[] memory _disputeKeys)
    public
    pure
    returns (bytes memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_committeePubKey`|`bytes`|The committee's aggregated public key (33 bytes compressed)|
|`_disputeKeys`|`bytes32[]`|Array of dispute keys for committee members (x-only, 32 bytes each)|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes`|The P2TR script pub key bytes|


### _getAcceptPeginP2TRScriptPub

Generates the Accept Pegin Taproot output script pub key with both key spend and script spend paths


```solidity
function _getAcceptPeginP2TRScriptPub(bytes memory _committeePubKey) internal pure returns (bytes memory);
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

Validates a speed-up output transactions

*Ensures the output is a valid P2WPKH for CPFP transactions to accelerate the parent transaction*


```solidity
function validateSpeedUpOutput(bytes32 _pubKey, BtcTxOut calldata _speedUpOut) external pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_pubKey`|`bytes32`|The user's public key (x-coordinate only, 32 bytes)|
|`_speedUpOut`|`BtcTxOut`|The Bitcoin transaction output containing the speed-up output|


### getSpeedUpScriptPub

Generates a P2WPKH script pub key for speed-up outputs

*Creates a P2WPKH script for Child Pays for Parent (CPFP) transactions to speed up the original transaction*


```solidity
function getSpeedUpScriptPub(bytes32 _pubKey) public pure returns (bytes memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_pubKey`|`bytes32`|The user's public key (x-coordinate only, 32 bytes)|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes`|The P2WPKH script pub key|


### getPegoutTxData

Calculates the signature hash for Bitcoin peg-out transactions

*Generates the hash that committee members must sign to authorize a peg-out*


```solidity
function getPegoutTxData(bytes memory _userPubKey, bytes32 _acceptPeginTx, PrevoutData[] memory _prevoutDatas)
    external
    pure
    returns (BitcoinSignatureData memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_userPubKey`|`bytes`|The user's public key in compressed format that will receive the funds|
|`_acceptPeginTx`|`bytes32`|The transaction id of the accept peg-in tx being spent|
|`_prevoutDatas`|`PrevoutData[]`|Array of prevout data for all inputs being spent (taptree + enabler outputs)|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`BitcoinSignatureData`|BitcoinSignatureData containing txid, signatureHash, and signatureMessage|


### _taprootSignatureHash

*Returns Signature Hash. The signature hash is the actual "message" that we sign when creating the signature.*

*It's a tagged hash of the common signature message, along with a sighash epoch prefix and the optional extension:*

*https://learnmeabitcoin.com/technical/upgrades/taproot/#signature-hash*


```solidity
function _taprootSignatureHash(uint8 _hashType, PrevoutData[] memory _prevoutDatas, BtcTransaction memory _btcTx)
    internal
    pure
    returns (bytes32, bytes memory);
```

