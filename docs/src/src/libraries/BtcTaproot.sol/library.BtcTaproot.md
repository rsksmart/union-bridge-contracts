# BtcTaproot
[Git Source](https://github.com/temp-rsk/bitvmx-union-bridge-contracts/blob/2c7f90ba21d83a98b646123c60d27a00fe0644fd/src/libraries/BtcTaproot.sol)

**Author:**
Fairgate

Functions needed to create Bitcoin Taproot scripts and addresses

*Implements Taproot functionality as specified in BIP-340, BIP-341, and BIP-342*

*Used for creating P2TR (Pay-to-Taproot) addresses and scripts in the union bridge*


## State Variables
### TAP_TWEAK
*Tag for TapTweak hash calculation*

*Used in the tweaked public key derivation process*


```solidity
bytes constant TAP_TWEAK = bytes("TapTweak");
```


### LEAF_VERSION
*Leaf version for Taproot scripts (0xc0 = 192)*

*Indicates this is a tapscript leaf in the script tree*


```solidity
bytes1 constant LEAF_VERSION = 0xc0;
```


### TAP_LEAF
*Tag for TapLeaf hash calculation*

*Used when hashing script leaves in the script tree*


```solidity
bytes constant TAP_LEAF = bytes("TapLeaf");
```


### TAP_BRANCH
*Tag for TapBranch hash calculation*

*Used when hashing branches in the script tree*


```solidity
bytes constant TAP_BRANCH = bytes("TapBranch");
```


### TAP_SIGHASH
*Tag for TapSighash calculation*

*Used when creating the signature hash for Taproot transactions*


```solidity
bytes constant TAP_SIGHASH = bytes("TapSighash");
```


## Functions
### taggedHash

Implements Bitcoin's tagged hash algorithm used in Taproot

*Computes sha256(tagHash || tagHash || data) where tagHash = sha256(tag)*

*This prevents hash collisions between different Taproot operations*

**Note:**
ref: https://github.com/bitcoin/bips/blob/master/bip-0340.mediawiki#tagged-hashes


```solidity
function taggedHash(bytes memory _tag, bytes memory _data) internal pure returns (bytes32);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_tag`|`bytes`|The tag string to use (e.g. "TapTweak", "TapLeaf", etc)|
|`_data`|`bytes`|The data to hash|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|taggedHash The tagged hash result|


### getSighash

Creates the signature hash for Taproot transactions

*Uses the TapSighash tag to create a unique hash for signing*

*See: https://learnmeabitcoin.com/technical/upgrades/taproot/#tweak*


```solidity
function getSighash(bytes memory data) internal pure returns (bytes32);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`data`|`bytes`|The transaction data to hash|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|The signature hash for the transaction|


### getTweak

Creates the tweak value for Taproot public key derivation

*Uses the TapTweak tag to create a tweak for the internal key*

*See: https://learnmeabitcoin.com/technical/upgrades/taproot/#tweak*


```solidity
function getTweak(bytes memory data) internal pure returns (bytes32);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`data`|`bytes`|The data to create the tweak from|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|The tweak value|


### getTweakedPublicKey

Derives the tweaked public key for Taproot

*Combines the internal public key with the tweak using elliptic curve operations*

*See: https://learnmeabitcoin.com/technical/upgrades/taproot/#tweaked-public-key*


```solidity
function getTweakedPublicKey(bytes32 _publicKey, bytes32 _tweak) internal pure returns (bytes32);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_publicKey`|`bytes32`|The internal public key (x-coordinate only)|
|`_tweak`|`bytes32`|The tweak value to apply|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|The tweaked public key (x-coordinate only)|


### getP2TRScriptPubKey

Creates a P2TR (Pay-to-Taproot) scriptPubKey

*Creates the script that locks funds to a Taproot address*

*See: https://learnmeabitcoin.com/technical/upgrades/taproot/#scriptpubkey*


```solidity
function getP2TRScriptPubKey(bytes32 tweakedPublicKey) internal pure returns (bytes memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`tweakedPublicKey`|`bytes32`|The tweaked public key (x-coordinate only)|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes`|The P2TR scriptPubKey bytes|


### getLeaf

Creates a leaf hash for the Taproot script tree

*Hashes a script with the TapLeaf tag to create a leaf in the script tree*

*See: https://learnmeabitcoin.com/technical/upgrades/taproot/#script-tree-merkle-root-leaf-hash*


```solidity
function getLeaf(bytes memory _script) internal pure returns (bytes32);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_script`|`bytes`|The script to hash|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|The leaf hash|


### getBranch

Creates a branch hash for the Taproot script tree

*Combines two leaves or branches with the TapBranch tag*

*See: https://learnmeabitcoin.com/technical/upgrades/taproot/#script-tree-merkle-root-branch-hash*


```solidity
function getBranch(bytes32 _leafOrBranch, bytes32 _otherLeafOrBranch) internal pure returns (bytes32);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_leafOrBranch`|`bytes32`|The first leaf or branch hash|
|`_otherLeafOrBranch`|`bytes32`|The second leaf or branch hash|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|The branch hash|


