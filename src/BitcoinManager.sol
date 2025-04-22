// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {console} from "forge-std/console.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {BaseProxy} from "./BaseProxy.sol";
import {PrevoutData, BtcTransaction, BtcTxOut, IBitcoinManager} from "./interfaces/IBitcoinManager.sol";
import {BytesHelper} from "./libraries/BytesHelper.sol";
import {BtcHelper} from "./libraries/BtcHelper.sol";
import {BtcTxEncoder} from "./libraries/BtcTxEncoder.sol";
import {BtcScriptParser} from "./libraries/BtcScriptParser.sol";
import {BtcTaproot} from "./libraries/BtcTaproot.sol";
import {Bech32m} from "src/libraries/Bech32m.sol";
import {OpCodes} from "./libraries/OpCodes.sol";
import {BtcNetwork} from "./libraries/Network.sol";
import {Constants} from "./libraries/Constants.sol";

/// @title BitcoinManager
/// @notice Manages Bitcoin Addresses and Scripts
contract BitcoinManager is IBitcoinManager, Initializable, BaseProxy {
    BtcNetwork public network;

    function initialize(address _initialOwner, BtcNetwork _network) public initializer {
        __BaseProxy_init(_initialOwner);
        network = _network;
    }

    /// @dev Convert Tx to raw tx hex using Bitcoin format and then uses hash256 to get the txHash
    function getBtcTxHash(BtcTransaction calldata _btcTx) external pure returns (bytes32) {
        return BtcHelper.hash256(BtcTxEncoder.encodeTx(_btcTx));
    }

    // ========================== Peg In Request ==========================
    /// @dev Generates a temporary peg in address for a peg in request
    function getTemporaryPegInAddress(
        address _rskDestinationAddress,
        uint64 _value,
        bytes32 _btcReimbursementPubKey,
        bytes32 _committeePubKey
    ) external view returns (string memory bitcoinDepositAddress) {
        validateRequestPegInInputs(_btcReimbursementPubKey, _committeePubKey, _rskDestinationAddress, _value);

        bytes32 tweakedPublicKey =
            getRequestPegInTweakedPublicKey(_rskDestinationAddress, _value, _btcReimbursementPubKey, _committeePubKey);

        return Bech32m.encodeTaprootAddress(abi.encodePacked(tweakedPublicKey), network);
    }

    /// @dev Generates the PegInRequest Taproot output script pub key with both key spend and script spend paths
    function getRequestPegInTweakedPublicKey(
        address _rskDestinationAddress,
        uint64 _value,
        bytes32 _btcReimbursementPubKey,
        bytes32 _committeePubKey
    ) internal pure returns (bytes32) {
        bytes memory timelockScript =
            BtcScriptParser.getTimelockScript(Constants.TIMELOCK_BLOCKS, _btcReimbursementPubKey);
        bytes32 timelockLeaf = BtcTaproot.getLeaf(timelockScript);

        // TODO Add this back once it's implemented in the protocol builder
        // bytes memory data = abi.encodePacked(_rskDestinationAddress, _value);
        // bytes memory extraDataScript = abi.encodePacked(OpCodes.OP_RETURN, OpCodes.OP_PUSHBYTES_28, data);
        // bytes32 extraDataLeaf = BtcTaproot.getLeaf(extraDataScript);

        bytes32 merkleRoot = timelockLeaf; // BtcTaproot.getBranch(timelockLeaf, extraDataLeaf);

        bytes32 tweak = BtcTaproot.getTweak(abi.encodePacked(_committeePubKey, merkleRoot));
        bytes32 tweakedPublicKey = BtcTaproot.getTweakedPublicKey(_committeePubKey, tweak);

        return tweakedPublicKey;
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
    }

    /// @dev Expected OP_RETURN format:
    /// @dev [OP_RETURN (1 byte)]
    /// @dev [OP_PUSHBYTES_69 (1 byte)]
    /// @dev [RSK_PEGIN (9 bytes)]
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

    /// @notice Validates output against a Taproot script with both key spend and script spend paths
    /// @param _rskDestinationAddress address that will get the RBTC
    /// @param _value amount sent in btc, should be equal to stream denomination
    /// @param _btcReimbursementPubKey The user's public key (x-only, 32 bytes)
    /// @param _committeePubKey The committee's public key (x-only, 32 bytes)
    /// @param _p2trOut The P2TR output of the peg in request
    function validatRequestPegInP2TROutput(
        address _rskDestinationAddress,
        uint64 _value,
        bytes32 _btcReimbursementPubKey,
        bytes32 _committeePubKey,
        BtcTxOut calldata _p2trOut
    ) external pure {
        // Validate that the amount is enough for the stream
        // TODO: Check if this is correct
        if (_p2trOut.amount < _value) {
            revert InvalidOutputAmount(_p2trOut.amount, _value);
        }
        validateRequestPegInInputs(_btcReimbursementPubKey, _committeePubKey, _rskDestinationAddress, _value);
        bytes memory p2trScriptPubKey =
            getPegInRequestP2TRScriptPub(_rskDestinationAddress, _value, _btcReimbursementPubKey, _committeePubKey);
        if (!BytesHelper.compare(_p2trOut.scriptPubKey, p2trScriptPubKey)) {
            revert IncorrectOutputScript(_p2trOut.scriptPubKey, p2trScriptPubKey);
        }
    }

    /// @dev Generates the PegInRequest Taproot output script pub key with both key spend and script spend paths
    function getPegInRequestP2TRScriptPub(
        address _rskDestinationAddress,
        uint64 _value,
        bytes32 _btcReimbursementPubKey,
        bytes32 _committeePubKey
    ) public pure returns (bytes memory) {
        bytes32 tweakedPublicKey =
            getRequestPegInTweakedPublicKey(_rskDestinationAddress, _value, _btcReimbursementPubKey, _committeePubKey);
        return BtcTaproot.getP2TRScriptPubKey(tweakedPublicKey);
    }

    // ========================== Peg In Accept ==========================
    /// @dev Generates the PegInAccept Taproot output script pub key with both key spend and script spend paths
    function getAcceptPegInTweakedPublicKey(bytes32 _committeePubKey) internal pure returns (bytes32) {
        // TODO add necesary tap scripts for take0, take1, etc

        // Currently we only consider the key spend path (user take)
        bytes32 tweak = BtcTaproot.getTweak(abi.encodePacked(_committeePubKey));
        bytes32 tweakedPublicKey = BtcTaproot.getTweakedPublicKey(_committeePubKey, tweak);

        return tweakedPublicKey;
    }

    /// @notice Validates output against a Taproot script with both key spend and script spend paths
    function validateAcceptPegInP2TROutput(bytes32 _committeePubKey, uint64 _inputAmount, BtcTxOut calldata _p2trOut)
        external
        pure
    {
        // Validate that the amount is enough to cover the fees
        // TODO: Check if this is correct
        uint64 inputMinusFees = _inputAmount - (Constants.P2TR_FEE + Constants.SPEED_UP_AMOUNT);
        if (_p2trOut.amount < inputMinusFees) {
            revert InvalidOutputAmount(_p2trOut.amount, inputMinusFees);
        }
        bytes memory p2trScriptPubKey = getAcceptPegInP2TRScriptPub(_committeePubKey);
        if (!BytesHelper.compare(_p2trOut.scriptPubKey, p2trScriptPubKey)) {
            revert IncorrectOutputScript(_p2trOut.scriptPubKey, p2trScriptPubKey);
        }
    }

    /// @dev Generates the PegInRequest Taproot output script pub key with both key spend and script spend paths
    function getAcceptPegInP2TRScriptPub(bytes32 _committeePubKey) public pure returns (bytes memory) {
        bytes32 tweakedPublicKey = getAcceptPegInTweakedPublicKey(_committeePubKey);
        return BtcTaproot.getP2TRScriptPubKey(tweakedPublicKey);
    }

    // ========================== Peg In Speed Up ==========================
    /// @dev Validates the speed up output
    function validateSpeedUpOutput(bytes32 _pubKey, BtcTxOut calldata _speedUpOut) external pure {
        if (_speedUpOut.amount < Constants.SPEED_UP_AMOUNT) {
            revert InvalidValue(_speedUpOut.amount, Constants.SPEED_UP_AMOUNT);
        }
        bytes memory p2wpkhScriptPubKey = getSpeedUpScriptPub(_pubKey);
        if (!BytesHelper.compare(_speedUpOut.scriptPubKey, p2wpkhScriptPubKey)) {
            revert IncorrectOutputScript(_speedUpOut.scriptPubKey, p2wpkhScriptPubKey);
        }
    }

    /// @dev Generates the PegInRequest Taproot output script pub key with both key spend and script spend paths
    function getSpeedUpScriptPub(bytes32 _pubKey) public pure returns (bytes memory) {
        // TODO change this to use P2WPSH with OP_1 so anyone can send the speed up
        // this should change at the same time as in the protocol builder
        return BtcScriptParser.getP2WPKHScript(abi.encodePacked(uint8(0x02), _pubKey));
    }

    function computePegOutTxHash(
        bytes memory usrPubKey,
        PrevoutData memory prevoutData,
        uint64 amount,
        uint64 speedUpAmount
    ) public pure returns (bytes32, bytes memory) {
        // Prepare the more complex parts of the data
        // sha_prevouts (32): the SHA256 of the serialization of all input outpoints.
        bytes32 sha_prevouts = sha256(abi.encodePacked(BtcHelper.reverseBytes32(prevoutData.txid), prevoutData.vout));

        // sha_amounts (32): the SHA256 of the serialization of all input outpoints amounts.
        bytes32 sha_amounts = sha256(abi.encodePacked(BtcHelper.reverseUint64(prevoutData.value)));

        // sha_scriptpubkeys (32): the SHA256 of the serialization of all spent output scriptPubKeys.
        bytes32 sha_scriptPubKeys =
            sha256(abi.encodePacked(BtcHelper.toCompactSize(prevoutData.scriptPubKey.length), prevoutData.scriptPubKey));

        //TODO: consider un-hardcoding, this value is used in little endian so it is reversed
        // sha_sequences (32): the SHA256 of the serialization of all input nSequences.
        bytes32 sha_sequences = sha256(abi.encodePacked(BtcHelper.reverseUint32(Constants.SEQUENCE)));

        // Prepare the outputs, user and speed up
        bytes memory scriptPubKey = BtcScriptParser.getP2WPKHScript(usrPubKey);
        bytes memory outputs = abi.encodePacked(
            BtcHelper.reverseUint64(amount), BtcHelper.toCompactSize(scriptPubKey.length), scriptPubKey
        );

        // User is in charge of the speedup to avoid reciclyng attacks
        bytes memory speedUpScriptPubKey = scriptPubKey;
        outputs = abi.encodePacked(
            outputs,
            BtcHelper.reverseUint64(speedUpAmount),
            BtcHelper.toCompactSize(speedUpScriptPubKey.length),
            speedUpScriptPubKey
        );

        // sha_outputs (32): the SHA256 of the serialization of all outputs in CTxOut format.
        bytes32 sha_outputs = sha256(outputs);

        // Concatenate all the data
        bytes memory encodedData = abi.encodePacked(
            uint8(0), // epoch
            uint8(0x01), // hash_type
            BtcHelper.reverseUint32(Constants.BTC_TX_VERSION), // nVersion
            Constants.LOCKTIME, // nLockTime
            sha_prevouts,
            sha_amounts,
            sha_scriptPubKeys,
            sha_sequences,
            sha_outputs,
            uint8(0), // spend_type
            uint32(0) // input_index
        );

        // Return the tagged hash and the encoded data before hashing
        return (BtcTaproot.taggedHash(BtcTaproot.TAP_SIGHASH, encodedData), encodedData);
    }
}
