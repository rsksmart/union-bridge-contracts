// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {console} from "forge-std/console.sol";
import {BtcTransaction, BtcTxOut, IBitcoinManager} from "./interfaces/IBitcoinManager.sol";
import {BtcHelper} from "./libraries/BtcHelper.sol";
import {BtcTxParser} from "./libraries/BtcTxParser.sol";
import {BytesHelper} from "./libraries/BytesHelper.sol";
import {BtcScriptParser} from "./libraries/BtcScriptParser.sol";
import {BtcAddressParser} from "./libraries/BtcAddressParser.sol";
import {OpCodes} from "./libraries/OpCodes.sol";

/// @title BitcoinManager
/// @notice Manages Bitcoin Addresses and Scripts
contract BitcoinManager is IBitcoinManager {
    uint8 constant TIMELOCK_BLOCKS = 10;

    function getTemporaryPegInAddress(
        address _rootstockDepositAddress,
        bytes32 _btcReimbursementPubKey,
        uint64 _value,
        bytes32 _committeeKey
    ) external pure returns (bytes memory bitcoinDepositAddress) {
        console.log("_committeeKey");
        console.logBytes32(_committeeKey);

        // Create custom tweak from deposit address and _value
        bytes32 customTweak = sha256(abi.encodePacked(_rootstockDepositAddress, _value));
        console.log("customTweak");
        console.logBytes32(customTweak);

        // Generate and return the taproot address
        bytes memory scriptPubKey = getPegInP2TRScriptPub(_btcReimbursementPubKey, _committeeKey);

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
    /// @dev [OP_PUSHBYTES_69 (1 byte)][RSK_PEGIN (9 bytes)]
    /// @dev [packet number (8 bytes)]
    /// @dev [rsk destination address (20 bytes)]
    /// @dev [reimbursement public key (32 bytes)]
    /// @dev Total expected size: 71 bytes
    function getPegInOpReturnData(BtcTxOut calldata _opReturnOut) external pure returns (uint64, address, bytes32) {
        uint8 expectedSize = (1 + 1 + 9 + 8 + 20 + 32);
        if (_opReturnOut.scriptPubKey.length != expectedSize) {
            revert invalidOpReturnLength(_opReturnOut.scriptPubKey.length, expectedSize);
        }

        // Validate OP_RETURN opcode
        uint8 index = 0;
        if (_opReturnOut.scriptPubKey[index] != OpCodes.OP_RETURN) {
            revert incorrectlyFormedOpReturn(index);
        }
        index++;

        // Validate PUSHBYTES op code
        if (_opReturnOut.scriptPubKey[index] != OpCodes.OP_PUSHBYTES_69) {
            revert incorrectlyFormedOpReturn(index);
        }
        index++;
        // Validate RSK_PEGIN flag
        if (
            !BytesHelper.stringCompare(
                BytesHelper.getBytesToString(_opReturnOut.scriptPubKey, index, index + 9), "RSK_PEGIN"
            )
        ) {
            revert incorrectlyFormedOpReturn(index);
        }
        index = index + 9;

        // Extract packet number
        uint64 packetNumber = BytesHelper.bytesToUint64(_opReturnOut.scriptPubKey, index);
        index = index + 8;

        // Extract RSK destination address
        address destinationAddress = BytesHelper.bytesToAddress(_opReturnOut.scriptPubKey, index);
        index = index + 20;

        // Extract Bitcoin reimbursement public key (x only)
        bytes32 btcReimbursementPubKey = BytesHelper.bytesToBytes32(_opReturnOut.scriptPubKey, index);
        // index = index + 32;

        return (packetNumber, destinationAddress, btcReimbursementPubKey);
    }

    /// @dev Validates a Bitcoin peg-in transaction
    function validatePegInP2TRData(BtcTxOut calldata _p2trOut, bytes32 _btcReimbursementPubKey, bytes32 _committeeKey)
        external
        pure
    {
        bytes memory p2trScriptPubKey = getPegInP2TRScriptPub(_btcReimbursementPubKey, _committeeKey);
        if (!BytesHelper.compare(_p2trOut.scriptPubKey, p2trScriptPubKey)) {
            revert incorrectP2TRScriptPub(_p2trOut.scriptPubKey, p2trScriptPubKey);
        }
    }

    /// @dev Convert Tx to raw tx hex using Bitcoin format and then uses hash256 to get the txHash
    function getBtcTxHash(BtcTransaction calldata _btcTx) external pure returns (bytes32) {
        return BtcHelper.hash256(BtcTxParser.encodeTx(_btcTx));
    }

    /// @notice Generates a Taproot script pub key with both key spend and script spend paths
    /// @param _btcReimbursementPubKey The committee's public key (x-only, 32 bytes)
    /// @param _committeeKey The committee's public key (x-only, 32 bytes)
    // /// @param customTweak Additional tweak data for address customization
    /// @return taprootScriptPubKey bytes (OP_1 + OP_PUSHBYTES_32 + 32 bytes output key)
    function getPegInP2TRScriptPub(
        bytes32 _btcReimbursementPubKey,
        bytes32 _committeeKey // Get the current packet's committee key bytes32)
    ) internal pure returns (bytes memory) {
        bytes32 timelockLeaf =
            BtcScriptParser.getLeaf(BtcScriptParser.getTimelockScript(TIMELOCK_BLOCKS, _btcReimbursementPubKey));
        // TODO add backup committee payment script
        // TODO should we do something with _rootstockDepositAddress here???

        // Convert to Taproot ScriptPubKey
        // If you only have one leaf in your script tree, the merkle root will be that leaf hash.
        return BtcAddressParser.getP2TRScriptPubKey(_committeeKey, timelockLeaf);
    }
}
