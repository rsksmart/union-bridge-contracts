# OpCodes
[Git Source](https://github.com/rsksmart/union-bridge-contracts/blob/68c14faa89612dfba1b7e9abf29455625661476f/src/libraries/OpCodes.sol)

Library containing Bitcoin script opcodes used for transaction validation

*This library defines all opcodes needed for Bitcoin script parsing and execution*

*Used for validating Bitcoin transaction scripts in the union bridge*

*Opcodes description can be found at https://en.bitcoin.it/wiki/Script*


## State Variables
### OP_DUP
*Duplicates the top stack item*

*Pushes a copy of the top item onto the stack*


```solidity
bytes1 public constant OP_DUP = 0x76;
```


### OP_HASH160
*Pop the top stack item and push its RIPEMD(SHA256) hash*

*Used for creating hash160 (RIPEMD160(SHA256(x))) of public keys*


```solidity
bytes1 public constant OP_HASH160 = 0xa9;
```


### OP_DROP
*Drops the top stack item*

*Removes the top item from the stack*


```solidity
bytes1 public constant OP_DROP = 0x75;
```


### OP_EQUALVERIFY
*Returns success if the inputs are exactly equal, failure otherwise*

*Pops two items from stack and verifies they are equal*


```solidity
bytes1 public constant OP_EQUALVERIFY = 0x88;
```


### OP_EQUAL
*Pushes 1 if the inputs are exactly equal, 0 otherwise*

*Pops two items from stack and pushes comparison result*


```solidity
bytes1 public constant OP_EQUAL = 0x87;
```


### OP_CHECKSIG
*Checks signature against public key and message*

*Pushes 1/0 for success/failure, see: https://en.bitcoin.it/wiki/OP_CHECKSIG*


```solidity
bytes1 public constant OP_CHECKSIG = 0xac;
```


### OP_CHECKSEQUENCEVERIFY
*Marks transaction as invalid if the relative lock time of the input is not equal to or longer than the value of the top stack item*

*The precise semantics are described in BIP 0112*

*Also known as OP_CSV (previously OP_NOP3)*


```solidity
bytes1 public constant OP_CHECKSEQUENCEVERIFY = 0xb2;
```


### OP_RETURN
*Fail the script immediately (Must be executed)*

*Used for OP_RETURN outputs to store data*


```solidity
bytes1 public constant OP_RETURN = 0x6a;
```


### OP_0
*An empty array of bytes is pushed onto the stack*

*This is not a no-op: an item is added to the stack*


```solidity
bytes1 public constant OP_0 = 0x00;
```


### OP_1
*Same as OP_PUSHNUM_1 - pushes the number 1 to the stack*


```solidity
bytes1 public constant OP_1 = 0x51;
```


### OP_PUSHNUM_16
*Pushes the number 16 to the stack*


```solidity
bytes1 public constant OP_PUSHNUM_16 = 0x60;
```


### OP_PUSHBYTES_1
*Pushes 1 byte of data to the stack*


```solidity
bytes1 public constant OP_PUSHBYTES_1 = 0x01;
```


### OP_PUSHBYTES_2
*Pushes 2 bytes of data to the stack*


```solidity
bytes1 public constant OP_PUSHBYTES_2 = 0x02;
```


### OP_PUSHBYTES_3
*Pushes 3 bytes of data to the stack*


```solidity
bytes1 public constant OP_PUSHBYTES_3 = 0x03;
```


### OP_PUSHBYTES_4
*Pushes 4 bytes of data to the stack*


```solidity
bytes1 public constant OP_PUSHBYTES_4 = 0x04;
```


### OP_PUSHBYTES_8
*Pushes 8 bytes of data to the stack*


```solidity
bytes1 public constant OP_PUSHBYTES_8 = 0x08;
```


### OP_PUSHBYTES_20
*Pushes 20 bytes of data to the stack*

*Commonly used for P2PKH addresses (RIPEMD160 hash)*


```solidity
bytes1 public constant OP_PUSHBYTES_20 = 0x14;
```


### OP_PUSHBYTES_24
*Pushes 24 bytes of data to the stack*


```solidity
bytes1 public constant OP_PUSHBYTES_24 = 0x18;
```


### OP_PUSHBYTES_28
*Pushes 28 bytes of data to the stack*


```solidity
bytes1 public constant OP_PUSHBYTES_28 = 0x1c;
```


### OP_PUSHBYTES_32
*Pushes 32 bytes of data to the stack*

*Commonly used for public keys and hashes*


```solidity
bytes1 public constant OP_PUSHBYTES_32 = 0x20;
```


### OP_PUSHBYTES_69
*Pushes 69 bytes of data to the stack*

*Commonly used for uncompressed public keys*


```solidity
bytes1 public constant OP_PUSHBYTES_69 = 0x45;
```


