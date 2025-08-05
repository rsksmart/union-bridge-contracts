# Constants
[Git Source](https://github.com/FairgateLabs/bitvmx-union-bridge-contracts/blob/b41d024ed73655cc3c392a6c92b6259ef625d19d/src/libraries/Constants.sol)

Library containing all constants used throughout the union bridge contracts

*This library defines Bitcoin transaction parameters, fee structures, and system configuration values*

*All constants are carefully chosen to ensure compatibility with Bitcoin and RSK networks*


## State Variables
### SEQUENCE
*Sequence number for replace-by-fee Bitcoin transactions (0xFFFFFFFD)*

*This enables replace-by-fee functionality for Bitcoin transactions*


```solidity
uint32 constant SEQUENCE = 0xFFFFFFFD;
```


### LOCKTIME
*Locktime value for Bitcoin transactions (0 = no locktime)*

*Used to specify when a transaction can be included in a block*


```solidity
uint32 constant LOCKTIME = 0;
```


### BTC_TX_VERSION
*Bitcoin transaction version (2 = supports SegWit and Taproot)*

*Version 2 enables modern Bitcoin features like Taproot*


```solidity
uint32 constant BTC_TX_VERSION = 2;
```


### VOUT_INDEX_TAPTREE
*Output index for Taproot output in peg-in Bitcoin transactions*

*First output (index 0) contains the main Taproot payment*


```solidity
uint32 constant VOUT_INDEX_TAPTREE = 0;
```


### VOUT_INDEX_SPEED_UP
*Output index for speed-up output in peg-in Bitcoin transactions*

*Second output (index 1) contains the speed-up payment for CPFP*


```solidity
uint32 constant VOUT_INDEX_SPEED_UP = 1;
```


### SIGHASH_ALL
*Signature hash type for Bitcoin transactions (SIGHASH_ALL = 0x01)*

*Indicates that all inputs and outputs are signed*


```solidity
uint8 constant SIGHASH_ALL = 0x01;
```


### P2TR_FEE
*Fee for P2TR Bitcoin transactions in satoshis*

*TODO: Check if this is correct for current network conditions*


```solidity
uint64 constant P2TR_FEE = 335;
```


### SPEED_UP_AMOUNT
*Speed-up amount in satoshis for CPFP Bitcoin transactions*

*Amount sent to speed-up output to accelerate parent transaction*


```solidity
uint64 constant SPEED_UP_AMOUNT = 300;
```


### DUST_THRESHOLD
*Dust threshold in satoshis for Bitcoin transactions*

*Minimum amount required for a Bitcoin output to be considered valid*


```solidity
uint64 constant DUST_THRESHOLD = 300;
```


### TIMELOCK_BLOCKS
*Timelock blocks for Bitcoin transactions*


```solidity
uint8 constant TIMELOCK_BLOCKS = 1;
```


### SIGNATURE_NONCE_LENGTH
*Length of signature nonce in bytes*

*Used for multi-signature operations in committee transactions*


```solidity
uint8 constant SIGNATURE_NONCE_LENGTH = 66;
```


### SLOTS_PER_PACKET
*Number of slots per packet in the stream*

*NOTE: SLOTS_PER_PACKET should be smaller than 2^16 to avoid overflow of Stream.pegoutSlotPointer*


```solidity
uint8 constant SLOTS_PER_PACKET = 100;
```


### SLOT_USAGE_THRESHOLD
*Threshold for slot usage that triggers new committee creation*

*When 80% of slots are filled, a new committee is created*


```solidity
uint8 constant SLOT_USAGE_THRESHOLD = 80;
```


### MAX_DENOMINATIONS_SIZE
*Maximum number of stream denominations supported by the bridge*

*Limits the number of different Bitcoin amounts that can be processed*


```solidity
uint64 constant MAX_DENOMINATIONS_SIZE = 10;
```


### MAX_CANDIDATES_SIZE_PER_ROLE
*Maximum number of candidates to a committee for a particular role and stream denominations*


```solidity
uint256 constant MAX_CANDIDATES_SIZE_PER_ROLE = 100;
```


