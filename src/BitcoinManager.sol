// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {console} from "forge-std/console.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {BaseProxy} from "./BaseProxy.sol";
import {BtcTransaction, BtcTxOut, IBitcoinManager} from "./interfaces/IBitcoinManager.sol";
import {BytesHelper} from "./libraries/BytesHelper.sol";
import {BtcHelper} from "./libraries/BtcHelper.sol";
import {BtcTxParser} from "./libraries/BtcTxParser.sol";
import {BtcScriptParser} from "./libraries/BtcScriptParser.sol";
import {BtcTaprootParser} from "./libraries/BtcTaprootParser.sol";
import {OpCodes} from "./libraries/OpCodes.sol";

/// @title BitcoinManager
/// @notice Manages Bitcoin Addresses and Scripts
contract BitcoinManager is IBitcoinManager, Initializable, BaseProxy {
    uint8 constant TIMELOCK_BLOCKS = 10;

    function initialize(address _initialOwner) public initializer {
        __BaseProxy_init(_initialOwner);
    }

    function getTemporaryPegInAddress(
        address _rskDestinationAddress,
        uint64 _value,
        bytes32 _btcReimbursementPubKey,
        bytes32 _committeePubKey
    ) external pure returns (bytes memory bitcoinDepositAddress) {
        validateRequestPegInInputs(_btcReimbursementPubKey, _committeePubKey, _rskDestinationAddress, _value);
        // Generate and return the taproot address
        bytes memory scriptPubKey =
            getPegInP2TRScriptPub(_rskDestinationAddress, _value, _btcReimbursementPubKey, _committeePubKey);

        // Add Taproot version byte (0x01) to script pub
        return abi.encodePacked(hex"01", scriptPubKey);
    }

    /// @dev Validates the inputs for a peg-in request
    function validateRequestPegInInputs(
        bytes32 _btcReimbursementPubKey,
        bytes32 _committeePubKey,
        address _rskDestinationAddress,
        uint64 _value
    ) internal pure {
        if (_btcReimbursementPubKey == bytes32(0)) {
            revert InvalidPublicKey(_btcReimbursementPubKey);
        }
        if (_committeePubKey == bytes32(0)) {
            revert InvalidPublicKey(_committeePubKey);
        }
        if (_rskDestinationAddress == address(0)) {
            revert InvalidAddress(_rskDestinationAddress);
        }
        if (_value == 0) {
            revert InvalidValue(_value);
        }
    }

    /// @dev Validates a Bitcoin peg-in transaction
    function validatePegInTx(BtcTransaction calldata _pegInBtcTx) external pure {
        if (_pegInBtcTx.outputs.length < 2) {
            revert IncorrectOutputNumber(uint64(_pegInBtcTx.outputs.length), 2);
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
            revert InvalidOpReturnLength(_opReturnOut.scriptPubKey.length, expectedSize);
        }

        // Validate OP_RETURN opcode
        uint8 index = 0;
        if (_opReturnOut.scriptPubKey[index] != OpCodes.OP_RETURN) {
            revert IncorrectlyFormedOpReturn(index);
        }
        index++;

        // Validate PUSHBYTES op code
        if (_opReturnOut.scriptPubKey[index] != OpCodes.OP_PUSHBYTES_69) {
            revert IncorrectlyFormedOpReturn(index);
        }
        index++;
        // Validate RSK_PEGIN flag
        if (!BytesHelper.stringCompare(BytesHelper.getBytesToString(_opReturnOut.scriptPubKey, index, 9), "RSK_PEGIN"))
        {
            revert IncorrectlyFormedOpReturn(index);
        }
        index = index + 9;

        // Extract packet number
        uint64 packetNumber = BytesHelper.bytesToUint64(_opReturnOut.scriptPubKey, index);
        index = index + 8;

        // Extract RSK destination address
        address rskDestinationAddress = BytesHelper.bytesToAddress(_opReturnOut.scriptPubKey, index);
        index = index + 20;

        // Extract Bitcoin reimbursement public key (x only)
        bytes32 btcReimbursementPubKey = BytesHelper.bytesToBytes32(_opReturnOut.scriptPubKey, index);
        // index = index + 32;

        return (packetNumber, rskDestinationAddress, btcReimbursementPubKey);
    }

    /// @dev Validates a Bitcoin peg-in transaction
    function validatePegInP2TRData(
        address _rskDestinationAddress,
        uint64 _value,
        bytes32 _btcReimbursementPubKey,
        bytes32 _committeePubKey,
        BtcTxOut calldata _p2trOut
    ) external pure {
        validateRequestPegInInputs(_btcReimbursementPubKey, _committeePubKey, _rskDestinationAddress, _value);
        bytes memory p2trScriptPubKey =
            getPegInP2TRScriptPub(_rskDestinationAddress, _value, _btcReimbursementPubKey, _committeePubKey);
        if (!BytesHelper.compare(_p2trOut.scriptPubKey, p2trScriptPubKey)) {
            revert IncorrectP2TRScriptPub(p2trScriptPubKey, _p2trOut.scriptPubKey);
        }
    }

    /// @dev Convert Tx to raw tx hex using Bitcoin format and then uses hash256 to get the txHash
    function getBtcTxHash(BtcTransaction calldata _btcTx) external pure returns (bytes32) {
        return BtcHelper.hash256(BtcTxParser.encodeTx(_btcTx));
    }

    /// @notice Generates a Taproot script pub key with both key spend and script spend paths
    /// @param _rskDestinationAddress address that will get the RBTC
    /// @param _value amount sent in btc, should be equal to stream denomination
    /// @param _btcReimbursementPubKey The committee's public key (x-only, 32 bytes)
    /// @param _committeePubKey The committee's public key (x-only, 32 bytes)
    // /// @param customTweak Additional tweak data for address customization
    /// @return taprootScriptPubKey bytes (OP_1 + OP_PUSHBYTES_32 + 32 bytes output key)
    function getPegInP2TRScriptPub(
        address _rskDestinationAddress,
        uint64 _value,
        bytes32 _btcReimbursementPubKey,
        bytes32 _committeePubKey
    ) internal pure returns (bytes memory) {
        bytes32 timelockLeaf =
            BtcTaprootParser.getLeaf(BtcScriptParser.getTimelockScript(TIMELOCK_BLOCKS, _btcReimbursementPubKey));
        // Use _rskDestinationAddress as part of the tweak
        bytes memory customTweakData = abi.encodePacked(_rskDestinationAddress, _value);
        // Convert to Taproot ScriptPubKey
        // If you only have one leaf in your script tree, the merkle root will be that leaf hash.
        return BtcTaprootParser.getP2TRScriptPubKey(_committeePubKey, timelockLeaf, customTweakData);
    }
}
