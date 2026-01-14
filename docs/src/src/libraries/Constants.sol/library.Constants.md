# Constants
[Git Source](https://github.com/temp-rsk/bitvmx-union-bridge-contracts/blob/0c819fa3fad6abf73f5f2a830cc21b001080582f/src/libraries/Constants.sol)

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


### REQUEST_PEGIN_VOUT_TAPTREE
*Output index for Taproot output in request peg-in Bitcoin transactions*

*First output (index 0) contains the main Taproot payment*


```solidity
uint32 constant REQUEST_PEGIN_VOUT_TAPTREE = 0;
```


### REQUEST_PEGIN_VOUT_OP_RETURN
*Output index for OP_RETURN output in request peg-in Bitcoin transactions*

*Second output (index 1) contains metadata: packet number, RSK address, BTC reimbursement key*


```solidity
uint32 constant REQUEST_PEGIN_VOUT_OP_RETURN = 1;
```


### REQUEST_PEGIN_VOUT_ENABLER
*Output index for enabler output in request peg-in Bitcoin transactions*

*Third output (index 2) contains the enabler output with dispute keys*


```solidity
uint32 constant REQUEST_PEGIN_VOUT_ENABLER = 2;
```


### REJECT_PEGIN_VIN_ENABLER
*Input index for consuming the request peg-in enabler output in reject peg-in Bitcoin transactions*

*First input (index 0) contains the rejected output by a member of the committee*


```solidity
uint32 constant REJECT_PEGIN_VIN_ENABLER = 0;
```


### ACCEPT_PEGIN_VIN_TAPTREE
*Input index for consuming the request peg-in taptree output in accept peg-in Bitcoin transactions*

*First input (index 0) spends the request peg-in taptree UTXO*


```solidity
uint32 constant ACCEPT_PEGIN_VIN_TAPTREE = 0;
```


### ACCEPT_PEGIN_VIN_ENABLER
*Input index for consuming the request peg-in enabler output in accept peg-in Bitcoin transactions*

*Second input (index 1) spends the request peg-in enabler UTXO*


```solidity
uint32 constant ACCEPT_PEGIN_VIN_ENABLER = 1;
```


### ACCEPT_PEGIN_VOUT_TAPTREE
*Output index for Taproot output in accept peg-in Bitcoin transactions*

*First output (index 0) contains the P2TR payment to the committee*


```solidity
uint32 constant ACCEPT_PEGIN_VOUT_TAPTREE = 0;
```


### ACCEPT_PEGIN_VOUT_ENABLER
*Output index for enabler output in accept peg-in Bitcoin transactions*

*Second output (index 1) contains the enabler output with operator dispute keys only*


```solidity
uint32 constant ACCEPT_PEGIN_VOUT_ENABLER = 1;
```


### ACCEPT_PEGIN_VOUT_SPEED_UP
*Output index for speed-up output in accept peg-in Bitcoin transactions*

*Third output (index 2) contains the speed-up payment for CPFP*


```solidity
uint32 constant ACCEPT_PEGIN_VOUT_SPEED_UP = 2;
```


### ADVANCE_FUNDS_VOUT_USER
*Output index for user output in advance funds Bitcoin transactions*

*First output (index 0) contains the payment to the user*


```solidity
uint32 constant ADVANCE_FUNDS_VOUT_USER = 0;
```


### ADVANCE_FUNDS_VOUT_OP_RETURN
*Output index for OP_RETURN output in advance funds Bitcoin transactions*

*Second output (index 1) contains metadata for tracking*


```solidity
uint32 constant ADVANCE_FUNDS_VOUT_OP_RETURN = 1;
```


### OPERATOR_TAKE_VIN_ACCEPT_PEGIN
*Input index for user input in operator take Bitcoin transactions*

*First input (index 0) spends the accept peg-in output UTXO*


```solidity
uint32 constant OPERATOR_TAKE_VIN_ACCEPT_PEGIN = 0;
```


### OPERATOR_TAKE_VIN_REIMBURSEMENT_KICKOFF
*Input index for reimbursement kickoff input in operator take Bitcoin transactions*

*Second input (index 1) spends the reimbursement kickoff UTXO*


```solidity
uint32 constant OPERATOR_TAKE_VIN_REIMBURSEMENT_KICKOFF = 1;
```


### OPERATOR_TAKE_VOUT_OPERATOR
*Output index for operator dispute key inoperator take Bitcoin transactions*

*First output (index 0) contains the payment to the operator's dispute key*


```solidity
uint32 constant OPERATOR_TAKE_VOUT_OPERATOR = 0;
```


### PEGOUT_VIN_TAPTREE
*Input index for consuming the accept peg-in taptree output in pegout Bitcoin transactions*

*First input (index 0) spends the accept peg-in taptree UTXO*


```solidity
uint32 constant PEGOUT_VIN_TAPTREE = 0;
```


### PEGOUT_VIN_ENABLER
*Input index for consuming the accept peg-in enabler output in pegout Bitcoin transactions*

*Second input (index 1) spends the accept peg-in enabler UTXO*


```solidity
uint32 constant PEGOUT_VIN_ENABLER = 1;
```


### PEGOUT_VOUT_USER
*Output index for user payment output in pegout Bitcoin transactions*

*First output (index 0) contains the payment to the user*


```solidity
uint32 constant PEGOUT_VOUT_USER = 0;
```


### PEGOUT_VOUT_SPEED_UP
*Output index for speed-up output in pegout Bitcoin transactions*

*Second output (index 1) contains the speed-up payment for CPFP*


```solidity
uint32 constant PEGOUT_VOUT_SPEED_UP = 1;
```


### REQUEST_PEGIN_OUTPUT_COUNT
*Number of outputs in a request peg-in transaction*

*Includes: taptree output, OP_RETURN metadata, and enabler output*


```solidity
uint32 constant REQUEST_PEGIN_OUTPUT_COUNT = 3;
```


### ACCEPT_PEGIN_INPUT_COUNT
*Number of inputs in an accept peg-in transaction*

*Includes: request pegin taptree input and request pegin enabler input*


```solidity
uint32 constant ACCEPT_PEGIN_INPUT_COUNT = 2;
```


### ACCEPT_PEGIN_OUTPUT_COUNT
*Number of outputs in an accept peg-in transaction*

*Includes: taptree output, enabler output, and speed-up output*


```solidity
uint32 constant ACCEPT_PEGIN_OUTPUT_COUNT = 3;
```


### PEGOUT_INPUT_COUNT
*Number of inputs in a pegout transaction*

*Includes: accept pegin taptree input and accept pegin enabler input*


```solidity
uint32 constant PEGOUT_INPUT_COUNT = 2;
```


### PEGOUT_OUTPUT_COUNT
*Number of outputs in a pegout transaction*

*Includes: user payment output and speed-up output*


```solidity
uint32 constant PEGOUT_OUTPUT_COUNT = 2;
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
uint64 constant SPEED_UP_AMOUNT = 540;
```


### ENABLER_AMOUNT
*Enabler output amount in satoshis for dispute resolution*

*Amount sent to enabler output for operator dispute mechanism*


```solidity
uint64 constant ENABLER_AMOUNT = 540;
```


### REIMBURSEMENT_KICKOFF_AMOUNT
*Reimbursement kickoff amount in satoshis for Bitcoin transactions*


```solidity
uint64 constant REIMBURSEMENT_KICKOFF_AMOUNT = 5137;
```


### DUST_THRESHOLD
*Dust threshold in satoshis for Bitcoin transactions*

*Minimum amount required for a Bitcoin output to be considered valid*


```solidity
uint64 constant DUST_THRESHOLD = 300;
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


