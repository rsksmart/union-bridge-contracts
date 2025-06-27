// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BtcHelper} from "./BtcHelper.sol";
import {BtcTransaction, BtcTxIn, BtcTxOut, PrevoutData} from "../interfaces/IBitcoinManager.sol";

/// @title Bitcoin Transaction Encoder
/// @notice Library for encoding and decoding Bitcoin transaction data
/// @dev Provides functions to convert Bitcoin transaction structures to raw hex format
/// @dev Used for creating and validating Bitcoin transactions in the union bridge
/// @author Fairgate
library BtcTxEncoder {
    /// @notice Encodes input outpoints (txId and vout) in Bitcoin format
    /// @dev Converts txId and vout to little endian format for Bitcoin compatibility
    /// @param _txId The transaction ID to encode
    /// @param _vout The output index to encode
    /// @return The encoded outpoint bytes
    function encodeInputsOutpoints(bytes32 _txId, uint32 _vout) internal pure returns (bytes memory) {
        return abi.encodePacked(BtcHelper.reverseBytes32(_txId), BtcHelper.reverseUint32(_vout));
    }

    /// @notice Encodes sequence number in Bitcoin format
    /// @dev Converts sequence to little endian format for Bitcoin compatibility
    /// @dev See: https://learnmeabitcoin.com/technical/transaction/#structure-input-count
    /// @param _sequence The sequence number to encode
    /// @return The encoded sequence in little endian
    function encodeSequence(uint32 _sequence) internal pure returns (uint32) {
        return BtcHelper.reverseUint32(_sequence);
    }

    /// @notice Encodes a script with its compact size prefix
    /// @dev Prepends the script length in compact size format to the script data
    /// @dev See: https://learnmeabitcoin.com/technical/transaction/#structure-input-count
    /// @param _script The script to encode
    /// @return The encoded script with size prefix
    function encodeScript(bytes memory _script) internal pure returns (bytes memory) {
        return abi.encodePacked(BtcHelper.toCompactSize(_script.length), _script);
    }

    /// @notice Encodes a complete transaction input in Bitcoin format
    /// @dev Combines outpoint, scriptSig, and sequence into a single input structure
    /// @dev See: https://learnmeabitcoin.com/technical/transaction/#structure-input-count
    /// @param _txId The transaction ID of the input being spent
    /// @param _vout The output index being spent
    /// @param _sequence The sequence number for the input
    /// @param _scriptSig The script signature (empty for non-legacy transactions)
    /// @return The encoded transaction input
    function encodeTxIn(bytes32 _txId, uint32 _vout, uint32 _sequence, bytes memory _scriptSig)
        internal
        pure
        returns (bytes memory)
    {
        return
            abi.encodePacked(encodeInputsOutpoints(_txId, _vout), encodeScript(_scriptSig), encodeSequence(_sequence));
    }

    /// @notice Converts an array of Bitcoin transaction inputs to raw hex format
    /// @dev Encodes all inputs with their count in compact size format
    /// @dev Format: [inputs count][txid0][vout0][script sig size 0][script sig 0][sequence0]...
    /// @param _inputs Array of transaction inputs to encode
    /// @return The encoded transaction inputs
    function encodeTxInputs(BtcTxIn[] memory _inputs) internal pure returns (bytes memory) {
        bytes memory hexInputs = BtcHelper.toCompactSize(_inputs.length);
        for (uint64 i = 0; i < _inputs.length; i++) {
            hexInputs = abi.encodePacked(
                hexInputs, encodeTxIn(_inputs[i].txId, _inputs[i].vout, _inputs[i].sequence, _inputs[i].scriptSig)
            );
        }
        return hexInputs;
    }

    /// @notice Encodes amount in Bitcoin format (little endian)
    /// @dev Converts amount to little endian format for Bitcoin compatibility
    /// @param _amount The amount in satoshis to encode
    /// @return The encoded amount in little endian
    function encodeAmount(uint64 _amount) internal pure returns (uint64) {
        return BtcHelper.reverseUint64(_amount);
    }

    /// @notice Encodes a complete transaction output in Bitcoin format
    /// @dev Combines amount and scriptPubKey into a single output structure
    /// @dev See: https://learnmeabitcoin.com/technical/transaction/#structure-outputs
    /// @param _amount The output amount in satoshis
    /// @param _scriptPubKey The script that locks the output
    /// @return The encoded transaction output
    function encodeTxOut(uint64 _amount, bytes memory _scriptPubKey) internal pure returns (bytes memory) {
        return abi.encodePacked(encodeAmount(_amount), encodeScript(_scriptPubKey));
    }

    /// @notice Converts an array of transaction outputs to raw hex format
    /// @dev Encodes all outputs with their count in compact size format
    /// @dev Format: [output count][amount0][script pubkey size 0][script pubkey 0]...
    /// @param _outputs Array of transaction outputs to encode
    /// @return The encoded transaction outputs
    function encodeTxOutputs(BtcTxOut[] memory _outputs) internal pure returns (bytes memory) {
        bytes memory hexOutputs = BtcHelper.toCompactSize(_outputs.length);
        for (uint64 i = 0; i < _outputs.length; i++) {
            hexOutputs = abi.encodePacked(hexOutputs, encodeTxOut(_outputs[i].amount, _outputs[i].scriptPubKey));
        }
        return hexOutputs;
    }

    /// @notice Encodes locktime in Bitcoin format (little endian)
    /// @dev Converts locktime to little endian format for Bitcoin compatibility
    /// @param _locktime The locktime value to encode
    /// @return The encoded locktime in little endian
    function encodeLocktime(uint32 _locktime) internal pure returns (uint32) {
        return BtcHelper.reverseUint32(_locktime);
    }

    /// @notice Encodes version in Bitcoin format (little endian)
    /// @dev Converts version to little endian format for Bitcoin compatibility
    /// @param _version The version number to encode
    /// @return The encoded version in little endian
    function encodeVersion(uint32 _version) internal pure returns (uint32) {
        return BtcHelper.reverseUint32(_version);
    }

    /// @notice Converts a complete Bitcoin transaction to raw hex format
    /// @dev Encodes the entire transaction structure for hash calculation
    /// @dev Format: [version][inputs][outputs][locktime]
    /// @dev See: https://learnmeabitcoin.com/technical/transaction/#structure
    /// @param _btcTx The Bitcoin transaction to encode
    /// @return The encoded transaction in raw hex format
    function encodeTx(BtcTransaction memory _btcTx) internal pure returns (bytes memory) {
        return abi.encodePacked(
            encodeVersion(_btcTx.version), // version needs to be converted to little Endian
            encodeTxInputs(_btcTx.inputs),
            encodeTxOutputs(_btcTx.outputs),
            encodeLocktime(_btcTx.locktime) // locktime needs to be converted to little Endian
        );
    }

    /// @notice Creates the common signature message for Taproot transaction signing
    /// @dev Implements the Taproot signature message format as specified in BIP-341
    /// @dev See: https://learnmeabitcoin.com/technical/upgrades/taproot/#common-signature-message
    /// @param _hashType The hash type for the signature
    /// @param prevoutDatas Array of previous output data for all inputs
    /// @param btcTx The Bitcoin transaction being signed
    /// @return The common signature message bytes
    function encodeCommonSignatureMessage(
        uint8 _hashType,
        PrevoutData[] memory prevoutDatas,
        BtcTransaction memory btcTx
    ) internal pure returns (bytes memory) {
        // Prepare the inputs
        (bytes32 sha_prevouts, bytes32 sha_amounts, bytes32 sha_scriptPubKeys, bytes32 sha_sequences) =
            getInputsShaForSignature(prevoutDatas, btcTx.inputs);

        // Prepare the outputs
        bytes32 sha_outputs = getOutputsShaForSignature(btcTx.outputs);

        // Concatenate all the data
        return abi.encodePacked(
            uint8(0), // epoch
            uint8(_hashType), // hash_type
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

    /// @notice Calculates SHA256 hashes for all input data needed in signature message
    /// @dev Creates four separate hashes for prevouts, amounts, scriptPubKeys, and sequences
    /// @param prevoutDatas Array of previous output data
    /// @param btcTxIns Array of transaction inputs
    /// @return sha_prevouts SHA256 of all input outpoints
    /// @return sha_amounts SHA256 of all input amounts
    /// @return sha_scriptPubKeys SHA256 of all spent output scriptPubKeys
    /// @return sha_sequences SHA256 of all input sequences
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

    /// @notice Calculates SHA256 hash of all transaction outputs for signature message
    /// @dev Creates a single hash of all outputs in CTxOut format
    /// @param btcTxOuts Array of transaction outputs
    /// @return sha_outputs SHA256 of all outputs in CTxOut format
    function getOutputsShaForSignature(BtcTxOut[] memory btcTxOuts) internal pure returns (bytes32) {
        bytes memory outputs;
        for (uint256 i = 0; i < btcTxOuts.length; i++) {
            outputs = abi.encodePacked(outputs, encodeTxOut(btcTxOuts[i].amount, btcTxOuts[i].scriptPubKey));
        }
        // sha_outputs (32): the SHA256 of the serialization of all outputs in CTxOut format.
        return sha256(outputs);
    }

    /// @notice Error thrown when prevout data length doesn't match transaction input length
    /// @param actual The actual length of prevout data array
    /// @param expected The expected length (should match transaction input count)
    error InvalidPrevoutDataLength(uint256 actual, uint256 expected);
}
