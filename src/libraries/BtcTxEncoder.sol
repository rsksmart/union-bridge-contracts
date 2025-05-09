// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BtcHelper} from "./BtcHelper.sol";
import {BtcTransaction, BtcTxIn, BtcTxOut, PrevoutData} from "../interfaces/IBitcoinManager.sol";

/**
 * @title Bitcoin Transaction Encoder
 * @notice Allows to encode / decode Bitcoin hex transactions
 * @author Fairgate
 */
library BtcTxEncoder {
    function encodeInputsOutpoints(bytes32 _txId, uint32 _vout) internal pure returns (bytes memory) {
        return abi.encodePacked(
            BtcHelper.reverseBytes32(_txId), // txId needs to be converted to little Endian
            BtcHelper.reverseUint32(_vout) // vout needs to be converted to little Endian
        );
    }

    function encodeSequence(uint32 _sequence) internal pure returns (uint32) {
        // See struct values https://learnmeabitcoin.com/technical/transaction/#structure-input-count
        // See hex format https://learnmeabitcoin.com/technical/transaction/wtxid/#segwit
        return BtcHelper.reverseUint32(_sequence); // sequence needs to be converted to little Endian
    }

    function encodeScript(bytes memory _script) internal pure returns (bytes memory) {
        // See struct values https://learnmeabitcoin.com/technical/transaction/#structure-input-count
        // See hex format https://learnmeabitcoin.com/technical/transaction/wtxid/#segwit
        return abi.encodePacked(
            BtcHelper.toCompactSize(_script.length), // scriptSize is compact-_size
            _script
        );
    }

    function encodeTxIn(bytes32 _txId, uint32 _vout, uint32 _sequence, bytes memory _scriptSig)
        internal
        pure
        returns (bytes memory)
    {
        // See struct values https://learnmeabitcoin.com/technical/transaction/#structure-input-count
        // See hex format https://learnmeabitcoin.com/technical/transaction/wtxid/#segwit
        return abi.encodePacked(
            encodeInputsOutpoints(_txId, _vout),
            encodeScript(_scriptSig), // scriptSig should be empty for non-legacy transactions
            encodeSequence(_sequence) // sequence needs to be converted to little Endian
        );
    }

    /// @dev Convert TxInputs to raw vin hex using Bitcoin format
    function encodeTxInputs(BtcTxIn[] memory _inputs) internal pure returns (bytes memory) {
        // [inputs count]
        // [txid0][vout0][script sig _size 0][script sig 0][sequence0]
        // [txid1][vout1][script sig _size 1][script sig 1][sequence1]...
        bytes memory hexInputs = BtcHelper.toCompactSize(_inputs.length);
        for (uint64 i = 0; i < _inputs.length; i++) {
            hexInputs = abi.encodePacked(
                hexInputs, encodeTxIn(_inputs[i].txId, _inputs[i].vout, _inputs[i].sequence, _inputs[i].scriptSig)
            );
        }
        return hexInputs;
    }

    function encodeAmount(uint64 _amount) internal pure returns (uint64) {
        return BtcHelper.reverseUint64(_amount);
    }

    function encodeTxOut(uint64 _amount, bytes memory _scriptPubKey) internal pure returns (bytes memory) {
        // See struct values https://learnmeabitcoin.com/technical/transaction/#structure-outputs
        // See hex format https://learnmeabitcoin.com/technical/transaction/wtxid/#segwit
        return abi.encodePacked(
            encodeAmount(_amount), // amount needs to be converted to little Endian
            encodeScript(_scriptPubKey) // scriptPubKeySize is compact-_size
        );
    }

    /// @dev Convert TxOutputs to raw vout hex using Bitcoin format
    function encodeTxOutputs(BtcTxOut[] memory _outputs) internal pure returns (bytes memory) {
        // [output count]
        // [amount0][script pubkey _size 0][script pubkey 0]
        // [amount1][script pubkey _size 1][script pubkey 1]...
        bytes memory hexOutputs = BtcHelper.toCompactSize(_outputs.length);
        for (uint64 i = 0; i < _outputs.length; i++) {
            hexOutputs = abi.encodePacked(hexOutputs, encodeTxOut(_outputs[i].amount, _outputs[i].scriptPubKey));
        }
        return hexOutputs;
    }

    function encodeLocktime(uint32 _locktime) internal pure returns (uint32) {
        return BtcHelper.reverseUint32(_locktime);
    }

    function encodeVersion(uint32 _version) internal pure returns (uint32) {
        return BtcHelper.reverseUint32(_version);
    }

    /// @dev Convert Tx to raw tx hex using Bitcoin format for getting the tx hash
    /// https://learnmeabitcoin.com/technical/transaction/#structure
    function encodeTx(BtcTransaction memory _btcTx) internal pure returns (bytes memory) {
        // [version][inputs][outputs][locktime]
        return abi.encodePacked(
            encodeVersion(_btcTx.version), // version needs to be converted to little Endian
            encodeTxInputs(_btcTx.inputs),
            encodeTxOutputs(_btcTx.outputs),
            encodeLocktime(_btcTx.locktime) // locktime needs to be converted to little Endian
        );
    }

    /// @dev Encode the data to sign a Bitcoin transaction
    function encodedDataToSign(PrevoutData[] memory prevoutDatas, BtcTransaction memory btcTx)
        internal
        pure
        returns (bytes memory)
    {
        // Prepare the inputs
        (bytes32 sha_prevouts, bytes32 sha_amounts, bytes32 sha_scriptPubKeys, bytes32 sha_sequences) =
            getInputsShaForSignature(prevoutDatas, btcTx.inputs);

        // Prepare the outputs
        bytes32 sha_outputs = getOutputsShaForSignature(btcTx.outputs);

        // Concatenate all the data
        return abi.encodePacked(
            uint8(0), // epoch
            uint8(0x01), // hash_type
            encodeVersion(btcTx.version), // nVersion
            encodeLocktime(btcTx.locktime), // nLockTime
            sha_prevouts,
            sha_amounts,
            sha_scriptPubKeys,
            sha_sequences,
            sha_outputs,
            uint8(0), // spend_type
            uint32(0) // input_index
        );
    }

    function getInputsShaForSignature(PrevoutData[] memory prevoutDatas, BtcTxIn[] memory btcTxIns)
        internal
        pure
        returns (bytes32, bytes32, bytes32, bytes32)
    {
        if (prevoutDatas.length != btcTxIns.length) {
            revert InvalidPrevoutDataLength(prevoutDatas.length, btcTxIns.length);
        }
        bytes memory encodedInputs;
        bytes memory encodedInputsAmounts;
        bytes memory encodedInputsScriptPubKeys;
        bytes memory encodedInputsSequences;
        for (uint256 i = 0; i < btcTxIns.length; i++) {
            encodedInputs = abi.encodePacked(encodedInputs, encodeInputsOutpoints(btcTxIns[i].txId, btcTxIns[i].vout));
            encodedInputsAmounts = abi.encodePacked(encodedInputsAmounts, encodeAmount(prevoutDatas[i].value));
            encodedInputsScriptPubKeys =
                abi.encodePacked(encodedInputsScriptPubKeys, encodeScript(prevoutDatas[i].scriptPubKey));
            encodedInputsSequences = abi.encodePacked(encodedInputsSequences, encodeSequence(btcTxIns[i].sequence));
        }
        // sha_prevouts (32): the SHA256 of the serialization of all input outpoints.
        bytes32 sha_prevouts = sha256(encodedInputs);
        // sha_amounts (32): the SHA256 of the serialization of all input outpoints amounts.
        bytes32 sha_amounts = sha256(encodedInputsAmounts);
        // sha_scriptpubkeys (32): the SHA256 of the serialization of all spent output scriptPubKeys.
        bytes32 sha_scriptPubKeys = sha256(encodedInputsScriptPubKeys);
        // sha_sequences (32): the SHA256 of the serialization of all input nSequences.
        bytes32 sha_sequences = sha256(encodedInputsSequences);

        return (sha_prevouts, sha_amounts, sha_scriptPubKeys, sha_sequences);
    }

    function getOutputsShaForSignature(BtcTxOut[] memory btcTxOuts) internal pure returns (bytes32) {
        bytes memory outputs;
        for (uint256 i = 0; i < btcTxOuts.length; i++) {
            outputs = abi.encodePacked(outputs, encodeTxOut(btcTxOuts[i].amount, btcTxOuts[i].scriptPubKey));
        }
        // sha_outputs (32): the SHA256 of the serialization of all outputs in CTxOut format.
        return sha256(outputs);
    }

    error InvalidPrevoutDataLength(uint256 actual, uint256 expected);
}
