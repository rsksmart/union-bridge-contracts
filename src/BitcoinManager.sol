// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {console} from "forge-std/console.sol";
import {BtcAddressParser} from "./libraries/BtcAddressParser.sol";
import {BtcTransaction, BtcTxOut, IBitcoinManager} from "./interfaces/IBitcoinManager.sol";
import {BtcHelper} from "./libraries/BtcHelper.sol";
import {BtcTxParser} from "./libraries/BtcTxParser.sol";
import {BytesHelper} from "./libraries/BytesHelper.sol";
import {OpCodes} from "./libraries/OpCodes.sol";

/// @title BitcoinManager
/// @notice Manages Bitcoin Addresses and Scripts
contract BitcoinManager is IBitcoinManager {
    function getTemporaryPegInAddress(
        address rootstockDepositAddress,
        // bytes calldata bitcoinReimbursementAddress,
        uint64 value,
        bytes32 committeeKey // Get the current packet's committee key
    ) external pure returns (bytes memory bitcoinDepositAddress) {
        console.log("committeeKey");
        console.logBytes32(committeeKey);

        // Create custom tweak from deposit address and value
        bytes32 customTweak = sha256(abi.encodePacked(rootstockDepositAddress, value));
        console.log("customTweak");
        console.logBytes32(customTweak);

        // Generate and return the taproot address
        bytes memory scriptPubKey = getPegInP2TRScriptPub(rootstockDepositAddress, value, committeeKey);

        // Add Taproot version byte (0x01) to script pub
        return abi.encodePacked(hex"01", scriptPubKey);
    }

    /// @dev Validates a Bitcoin peg-in transaction
    function validatePegInTx(BtcTransaction calldata _pegInBtcTx) external pure {
        if (_pegInBtcTx.outputs.length < 2) {
            revert incorrectOutputNumber(uint64(_pegInBtcTx.outputs.length), 2);
        }
    }

    /// @dev Expected OP_RETURN format:
    /// @dev [OP_RETURN (1 byte)]
    /// @dev [OP_PUSHBYTES_9 (1 byte)][RSK_PEGIN (9 bytes)]
    /// @dev [OP_PUSHBYTES_8 (1 byte)][packet number (8 bytes)]
    /// @dev [OP_PUSHBYTES_20 (1 byte)][rsk destination address (20 bytes)]
    /// @dev [OP_PUSHBYTES_62 (1 byte)][reimbursement address (62 bytes)]
    /// @dev Total expected size: 104 bytes
    function getPegInOpReturnData(BtcTxOut calldata _opReturnOut)
        external
        pure
        returns (uint64, address, string memory)
    {
        uint8 expectedSize = (1 + 1 + 9 + 1 + 8 + 1 + 20 + 1 + 62);
        if (_opReturnOut.scriptPubKey.length != expectedSize) {
            revert invalidOpReturnLength(_opReturnOut.scriptPubKey.length, expectedSize);
        }

        // Validate OP_RETURN opcode
        uint8 index = 0;
        if (_opReturnOut.scriptPubKey[index] != OpCodes.OP_RETURN) {
            revert incorrectlyFormedOpReturn(index);
        }
        index++;

        // Validate RSK_PEGIN flag
        if (_opReturnOut.scriptPubKey[index] != OpCodes.OP_PUSHBYTES_9) {
            revert incorrectlyFormedOpReturn(index);
        }
        index++;
        if (
            !BytesHelper.stringCompare(
                BytesHelper.bytesToString(_opReturnOut.scriptPubKey, index, index + 9), "RSK_PEGIN"
            )
        ) {
            revert incorrectlyFormedOpReturn(index);
        }
        index = index + 9;

        // Extract packet number
        if (_opReturnOut.scriptPubKey[index] != OpCodes.OP_PUSHBYTES_8) {
            revert incorrectlyFormedOpReturn(index);
        }
        index++;
        uint64 packetNumber = BytesHelper.bytesToUint64(_opReturnOut.scriptPubKey, index);
        index = index + 8;

        // Extract RSK destination address
        if (_opReturnOut.scriptPubKey[index] != OpCodes.OP_PUSHBYTES_20) {
            revert incorrectlyFormedOpReturn(index);
        }
        index++;
        address destinationAddress = BytesHelper.bytesToAddress(_opReturnOut.scriptPubKey, index);
        index = index + 20;

        // Extract Bitcoin reimbursement address
        if (_opReturnOut.scriptPubKey[index] != OpCodes.OP_PUSHBYTES_62) {
            revert incorrectlyFormedOpReturn(index);
        }
        index++;
        string memory btcReinburstmentAddress = BytesHelper.bytesToString(_opReturnOut.scriptPubKey, index, index + 62);
        index = index + 62;

        return (packetNumber, destinationAddress, btcReinburstmentAddress);
    }

    /// @dev Validates a Bitcoin peg-in transaction
    function validatePegInP2TRData(
        BtcTxOut calldata p2trOut,
        address rootstockDepositAddress,
        // bytes calldata bitcoinReimbursementAddress,
        bytes32 committeeKey
    ) external pure {
        bytes memory p2trScriptPubKey = getPegInP2TRScriptPub(rootstockDepositAddress, p2trOut.amount, committeeKey);
        if (!BytesHelper.compare(p2trOut.scriptPubKey, p2trScriptPubKey)) {
            revert incorrectP2TRScriptPub(p2trOut.scriptPubKey, p2trScriptPubKey);
        }
    }

    /// @dev Convert Tx to raw tx hex using Bitcoin format and then uses hash256 to get the txHash
    function getBtcTxHash(BtcTransaction calldata _btcTx) external pure returns (bytes32) {
        return BtcHelper.hash256(BtcTxParser.encodeTx(_btcTx));
    }

    /// @notice Generates a Taproot script pub key with both key spend and script spend paths
    /// @param rootstockDepositAddress The RSK address to deposit pegged in RBTC
    /// @param committeeKey The committee's public key (x-only, 32 bytes)
    // /// @param customTweak Additional tweak data for address customization
    /// @return taprootScriptPubKey bytes (OP_1 + OP_PUSHBYTES_32 + 32 bytes output key)
    function getPegInP2TRScriptPub(
        address rootstockDepositAddress,
        // string calldata bitcoinReimbursementAddress,
        uint64 value,
        bytes32 committeeKey // Get the current packet's committee key bytes32)
    ) internal pure returns (bytes memory) {
        // TODO make actual script root with other spending paths
        // using timelock, DAG and ZK proof
        bytes32 scriptRoot = bytes32(0);

        // Convert to Taproot ScriptPubKey
        return BtcAddressParser.getP2TRScriptPathScriptPubKey(committeeKey, scriptRoot);
    }
}
