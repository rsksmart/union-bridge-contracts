// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Inspired by https://github.com/rsksmart/btc-transaction-solidity-helper/blob/main/contracts/OpCodes.sol
// Opcodes description https://en.bitcoin.it/wiki/Script
// All opcodes in rust https://docs.rs/syscoin/latest/src/bitcoin/blockdata/opcodes.rs.html
library OpCodes {
    /// Duplicates the top stack item
    bytes1 public constant OP_DUP = 0x76;
    /// Pop the top stack item and push its RIPEMD(SHA256) hash
    bytes1 public constant OP_HASH160 = 0xa9;
    /// Returns success if the inputs are exactly equal, failure otherwise
    bytes1 public constant OP_EQUALVERIFY = 0x88;
    /// https://en.bitcoin.it/wiki/OP_CHECKSIG pushing 1/0 for success/failure
    bytes1 public constant OP_CHECKSIG = 0xac;
    /// Fail the script immediately. (Must be executed.)
    bytes1 public constant OP_RETURN = 0x6a;
    /// Pushes 1 if the inputs are exactly equal, 0 otherwise
    bytes1 public constant OP_EQUAL = 0x87;
    /// Marks transaction as invalid if the relative lock time of the input (enforced by BIP 0068 with nSequence)
    /// is not equal to or longer than the value of the top stack item.
    /// The precise semantics are described in BIP 0112.
    bytes1 public constant OP_CHECKSEQUENCEVERIFY = 0xb2; // aka OP_CSV (previously OP_NOP3)
    /// Drops the top stack item
    bytes1 public constant OP_DROP = 0x75;

    /// An empty array of bytes is pushed onto the stack. (This is not a no-op: an item is added to the stack.)
    bytes1 public constant OP_0 = 0x00;
    /// @dev Same as OP_PUSHNUM_1 This opcode is used to push the number 1 to the stack.
    bytes1 public constant OP_1 = 0x51;
    bytes1 public constant OP_PUSHNUM_16 = 0x60;

    bytes1 public constant OP_PUSHBYTES_1 = 0x01;
    bytes1 public constant OP_PUSHBYTES_2 = 0x02;
    bytes1 public constant OP_PUSHBYTES_3 = 0x03;
    bytes1 public constant OP_PUSHBYTES_4 = 0x04;
    bytes1 public constant OP_PUSHBYTES_8 = 0x08;
    bytes1 public constant OP_PUSHBYTES_20 = 0x14;
    bytes1 public constant OP_PUSHBYTES_24 = 0x18;
    bytes1 public constant OP_PUSHBYTES_28 = 0x1c;
    bytes1 public constant OP_PUSHBYTES_32 = 0x20;
    bytes1 public constant OP_PUSHBYTES_69 = 0x45;
}
