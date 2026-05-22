// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title OpCodes
/// @notice Library containing Bitcoin script opcodes used for transaction validation
/// @dev This library defines all opcodes needed for Bitcoin script parsing and execution
/// @dev Used for validating Bitcoin transaction scripts in the union bridge
/// @dev Opcodes description can be found at https://en.bitcoin.it/wiki/Script
library OpCodes {
    // Stack Operations
    /// @dev Duplicates the top stack item
    /// @dev Pushes a copy of the top item onto the stack
    bytes1 public constant OP_DUP = 0x76;

    /// @dev Pop the top stack item and push its RIPEMD(SHA256) hash
    /// @dev Used for creating hash160 (RIPEMD160(SHA256(x))) of public keys
    bytes1 public constant OP_HASH160 = 0xa9;

    /// @dev Drops the top stack item
    /// @dev Removes the top item from the stack
    bytes1 public constant OP_DROP = 0x75;

    // Comparison Operations
    /// @dev Returns success if the inputs are exactly equal, failure otherwise
    /// @dev Pops two items from stack and verifies they are equal
    bytes1 public constant OP_EQUALVERIFY = 0x88;

    /// @dev Pushes 1 if the inputs are exactly equal, 0 otherwise
    /// @dev Pops two items from stack and pushes comparison result
    bytes1 public constant OP_EQUAL = 0x87;

    // Cryptographic Operations
    /// @dev Checks signature against public key and message
    /// @dev Pushes 1/0 for success/failure, see: https://en.bitcoin.it/wiki/OP_CHECKSIG
    bytes1 public constant OP_CHECKSIG = 0xac;

    // Control Flow Operations
    /// @dev Marks transaction as invalid if the relative lock time of the input is not equal to or longer than the value of the top stack item
    /// @dev The precise semantics are described in BIP 0112
    /// @dev Also known as OP_CSV (previously OP_NOP3)
    bytes1 public constant OP_CHECKSEQUENCEVERIFY = 0xb2;

    // Data Operations
    /// @dev Fail the script immediately (Must be executed)
    /// @dev Used for OP_RETURN outputs to store data
    bytes1 public constant OP_RETURN = 0x6a;

    // Push Operations
    /// @dev An empty array of bytes is pushed onto the stack
    /// @dev This is not a no-op: an item is added to the stack
    bytes1 public constant OP_0 = 0x00;

    /// @dev Same as OP_PUSHNUM_1 - pushes the number 1 to the stack
    bytes1 public constant OP_1 = 0x51;

    /// @dev Pushes the number 16 to the stack
    bytes1 public constant OP_PUSHNUM_16 = 0x60;

    // Push Byte Operations
    /// @dev Pushes 1 byte of data to the stack
    bytes1 public constant OP_PUSHBYTES_1 = 0x01;

    /// @dev Pushes 2 bytes of data to the stack
    bytes1 public constant OP_PUSHBYTES_2 = 0x02;

    /// @dev Pushes 3 bytes of data to the stack
    bytes1 public constant OP_PUSHBYTES_3 = 0x03;

    /// @dev Pushes 4 bytes of data to the stack
    bytes1 public constant OP_PUSHBYTES_4 = 0x04;

    /// @dev Pushes 8 bytes of data to the stack
    bytes1 public constant OP_PUSHBYTES_8 = 0x08;

    /// @dev Pushes 20 bytes of data to the stack
    /// @dev Commonly used for P2PKH addresses (RIPEMD160 hash)
    bytes1 public constant OP_PUSHBYTES_20 = 0x14;

    /// @dev Pushes 24 bytes of data to the stack
    bytes1 public constant OP_PUSHBYTES_24 = 0x18;

    /// @dev Pushes 28 bytes of data to the stack
    bytes1 public constant OP_PUSHBYTES_28 = 0x1c;

    /// @dev Pushes 32 bytes of data to the stack
    /// @dev Commonly used for public keys and hashes
    bytes1 public constant OP_PUSHBYTES_32 = 0x20;

    /// @dev Pushes 69 bytes of data to the stack
    /// @dev Commonly used for uncompressed public keys
    bytes1 public constant OP_PUSHBYTES_69 = 0x45;
}
