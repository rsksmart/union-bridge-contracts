// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {OpCodes} from "./OpCodes.sol";
import {BtcTransaction, BtcTxIn, BtcTxOut} from "../interfaces/IBitcoinManager.sol";

/**
 * @title Btc Utils
 * @notice Usefull functions for Bitcoin parsin/encoding/decoding
 * @author Fairgate
 */
library BtcUtils {
    function encodeTxIn(bytes32 _txId, uint32 _vout, uint32 _sequence, bytes memory _scriptSig)
        internal
        pure
        returns (bytes memory)
    {
        // See struct values https://learnmeabitcoin.com/technical/transaction/#structure-input-count
        // See hex format https://learnmeabitcoin.com/technical/transaction/wtxid/#segwit
        return abi.encodePacked(
            reverseBytes32(_txId), // txId needs to be converted to little Endian
            reverseUint32(_vout), // vout needs to be converted to little Endian
            toCompactSize(_scriptSig.length), // scriptSigSize is compact-_size
            _scriptSig, // scriptSig should be empty for non-legacy transactions
            reverseUint32(_sequence) // sequence needs to be converted to little Endian
        );
    }

    /// @dev Convert TxInputs to raw vin hex using Bitcoin format
    function encodeTxInputs(BtcTxIn[] memory _inputs) internal pure returns (bytes memory) {
        // [inputs count]
        // [txid0][vout0][script sig _size 0][script sig 0][sequence0]
        // [txid1][vout1][script sig _size 1][script sig 1][sequence1]...
        bytes memory hexInputs = toCompactSize(_inputs.length);
        for (uint64 i = 0; i < _inputs.length; i++) {
            hexInputs = abi.encodePacked(
                hexInputs, encodeTxIn(_inputs[i].txId, _inputs[i].vout, _inputs[i].sequence, _inputs[i].scriptSig)
            );
        }
        return hexInputs;
    }

    function encodeTxOut(uint64 _amount, bytes memory _scriptPubKey) internal pure returns (bytes memory) {
        // See struct values https://learnmeabitcoin.com/technical/transaction/#structure-outputs
        // See hex format https://learnmeabitcoin.com/technical/transaction/wtxid/#segwit
        return abi.encodePacked(
            reverseUint64(_amount), // amount needs to be converted to little Endian
            toCompactSize(_scriptPubKey.length), // scriptPubKeySize is compact-_size
            _scriptPubKey
        );
    }

    /// @dev Convert TxOutputs to raw vout hex using Bitcoin format
    function encodeTxOutputs(BtcTxOut[] memory _outputs) internal pure returns (bytes memory) {
        // [output count]
        // [amount0][script pubkey _size 0][script pubkey 0]
        // [amount1][script pubkey _size 1][script pubkey 1]...
        bytes memory hexOutputs = toCompactSize(_outputs.length);
        for (uint64 i = 0; i < _outputs.length; i++) {
            hexOutputs = abi.encodePacked(hexOutputs, encodeTxOut(_outputs[i].amount, _outputs[i].scriptPubKey));
        }
        return hexOutputs;
    }

    /// @dev Convert Tx to raw tx hex using Bitcoin format for getting the tx hash
    /// https://learnmeabitcoin.com/technical/transaction/#structure
    function encodeTx(BtcTransaction memory _btcTx) internal pure returns (bytes memory) {
        // [version][inputs][outputs][locktime]
        return abi.encodePacked(
            reverseUint32(_btcTx.version), // version needs to be converted to little Endian
            encodeTxInputs(_btcTx.inputs),
            encodeTxOutputs(_btcTx.outputs),
            reverseUint32(_btcTx.locktime) // locktime needs to be converted to little Endian
        );
    }

    /// @dev This is how Bitcoin calls double sha256 and we reverse it to correct endian
    function hash256(bytes memory _toHash) internal pure returns (bytes32) {
        bytes32 littleEndianHash = sha256(abi.encode(sha256(_toHash)));
        // reverse bits
        // converts from little endian (used by Bitcoin) to big endian (used by humans)
        // https://learnmeabitcoin.com/technical/general/byte-order/#:~:text=In%20both%20transaction%20and%20block,we%20humans%20write%20numbers%20down.
        return reverseBytes32(littleEndianHash);
    }

    function reverseBytes32(bytes32 _input) internal pure returns (bytes32 v) {
        // Function to reverse bytes
        // https://ethereum.stackexchange.com/questions/83626/how-to-reverse-byte-order-in-uint256-or-bytes32#answer-83627
        v = _input;

        // swap bytes
        v = ((v & 0xFF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00) >> 8)
            | ((v & 0x00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF) << 8);

        // swap 2-byte long pairs
        v = ((v & 0xFFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000) >> 16)
            | ((v & 0x0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF) << 16);

        // swap 4-byte long pairs
        v = ((v & 0xFFFFFFFF00000000FFFFFFFF00000000FFFFFFFF00000000FFFFFFFF00000000) >> 32)
            | ((v & 0x00000000FFFFFFFF00000000FFFFFFFF00000000FFFFFFFF00000000FFFFFFFF) << 32);

        // swap 8-byte long pairs
        v = ((v & 0xFFFFFFFFFFFFFFFF0000000000000000FFFFFFFFFFFFFFFF0000000000000000) >> 64)
            | ((v & 0x0000000000000000FFFFFFFFFFFFFFFF0000000000000000FFFFFFFFFFFFFFFF) << 64);

        // swap 16-byte long pairs
        v = (v >> 128) | (v << 128);
    }

    /// @notice          Changes the endianness of a uint64
    /// @param _b        The unsigned integer to reverse
    /// @return v        The reversed value
    /// https://github.com/bob-collective/bitcoin-spv/blob/8f375250198ff5d2fb95ee2ccf72d835cd7ca4c2/src/BTCUtils.sol
    function reverseUint64(uint64 _b) internal pure returns (uint64 v) {
        v = _b;

        // swap bytes
        v = ((v >> 8) & 0x00FF00FF00FF00FF) | ((v & 0x00FF00FF00FF00FF) << 8);
        // swap 2-byte long pairs
        v = ((v >> 16) & 0x0000FFFF0000FFFF) | ((v & 0x0000FFFF0000FFFF) << 16);
        // swap 4-byte long pairs
        v = (v >> 32) | (v << 32);
    }

    /// @notice          Changes the endianness of a uint32
    /// @param _b        The unsigned integer to reverse
    /// @return v        The reversed value
    /// https://github.com/bob-collective/bitcoin-spv/blob/8f375250198ff5d2fb95ee2ccf72d835cd7ca4c2/src/BTCUtils.sol
    function reverseUint32(uint32 _b) internal pure returns (uint32 v) {
        v = _b;

        // swap bytes
        v = ((v >> 8) & 0x00FF00FF) | ((v & 0x00FF00FF) << 8);
        // swap 2-byte long pairs
        v = (v >> 16) | (v << 16);
    }

    /// @notice          Changes the endianness of a uint16
    /// @param _b        The unsigned integer to reverse
    /// @return v        The reversed value
    /// https://github.com/bob-collective/bitcoin-spv/blob/8f375250198ff5d2fb95ee2ccf72d835cd7ca4c2/src/BTCUtils.sol
    function reverseUint16(uint16 _b) internal pure returns (uint16 v) {
        v = (_b << 8) | (_b >> 8);
    }

    /// @dev returns hex bytes with _size in btc compact _size
    /// The first byte indicates which bytes encode the integer:
    /// <= FC – This byte (0 - 252)
    /// FD – The next two bytes (253 - 65535)
    /// FE – The next four bytes (65536 - 4294967295)
    /// FF – The next eight bytes (4294967296 - 18446744073709551615)
    // Note: Bytes encoding the integer are in little endian.
    // https://learnmeabitcoin.com/technical/general/compact-_size/
    function toCompactSize(uint256 _size) internal pure returns (bytes memory) {
        if (_size <= 252) {
            return abi.encodePacked(uint8(_size));
        } else if (_size <= 65535) {
            return abi.encodePacked(uint8(0xFD), reverseUint16(uint16(_size)));
        } else if (_size <= 4294967295) {
            return abi.encodePacked(uint8(0xFE), reverseUint32(uint32(_size)));
        }
        return abi.encodePacked(uint8(0xFF), reverseUint64(uint64(_size)));
    }
}
