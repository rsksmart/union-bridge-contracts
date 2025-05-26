// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {BaseProxy} from "./BaseProxy.sol";
import {PrevoutData, BtcTransaction, BtcTxIn, BtcTxOut, IBitcoinManager} from "./interfaces/IBitcoinManager.sol";
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
        network = _network;
        __BaseProxy_init(_initialOwner);
    }

    /// @dev Convert Tx to raw tx hex using Bitcoin format and then uses hash256 to get the txHash
    function getBtcTxHash(BtcTransaction calldata _btcTx) external pure returns (bytes32) {
        return _getBtcTxHash(_btcTx);
    }

    function _getBtcTxHash(BtcTransaction memory _btcTx) internal pure returns (bytes32) {
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
    /// @dev Get the signature hash for a peg in accept transaction
    function getAcceptPegInSignatureHash(
        bytes32 _committeePubKey,
        bytes32 _userXOnlyPubKey,
        bytes32 _registerPegInTx,
        PrevoutData memory _prevoutData
    ) external pure returns (bytes32, bytes32, bytes memory) {
        // Prepare the inputs
        BtcTxIn[] memory btcInputs = new BtcTxIn[](1);
        btcInputs[0] = BtcTxIn({
            txId: _registerPegInTx,
            vout: Constants.VOUT_INDEX_TAPTREE,
            scriptSig: bytes(""),
            sequence: Constants.SEQUENCE
        });

        // Add inputs previous output data
        PrevoutData[] memory prevoutDatas = new PrevoutData[](1);
        prevoutDatas[0] = _prevoutData;

        // Prepare the outputs, committee and speed up
        BtcTxOut[] memory btcOutputs = new BtcTxOut[](2);

        // Calculate fee and speedUpAmount from amount
        // TODO: atm is returning hardcoded values, should be calculated
        (uint64 fee, uint64 speedUpAmount) = BtcHelper.calculateFeeAndSpeedUp(_prevoutData.value);

        // Committee accept pegin
        bytes memory scriptPubKey = getAcceptPegInP2TRScriptPub(_committeePubKey);
        btcOutputs[0] = BtcTxOut({amount: _prevoutData.value - fee - speedUpAmount, scriptPubKey: scriptPubKey});

        // Speed up
        bytes memory speedUpScriptPubKey = getSpeedUpScriptPub(_userXOnlyPubKey);
        btcOutputs[1] = BtcTxOut({amount: speedUpAmount, scriptPubKey: speedUpScriptPubKey});

        // Prepare Btc Transaction
        BtcTransaction memory pegInAcceptTx = BtcTransaction({
            version: Constants.BTC_TX_VERSION,
            locktime: Constants.LOCKTIME,
            inputs: btcInputs,
            outputs: btcOutputs
        });
        bytes32 txHash = _getBtcTxHash(pegInAcceptTx);
        // Return the tagged hash and the encoded data before hashing
        (bytes32 acceptPeginSignatureHash, bytes memory acceptPeginSignatureMessage) =
            taprootSignatureHash(Constants.SIGHASH_ALL, prevoutDatas, pegInAcceptTx);
        return (txHash, acceptPeginSignatureHash, acceptPeginSignatureMessage);
    }

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

    // ========================== Peg Out Signature Hash ==========================
    /// @dev Get the signature hash for a peg out transaction
    function getPegOutSignatureHash(bytes memory _usrPubKey, bytes32 _acceptPegInTx, PrevoutData memory _prevoutData)
        external
        pure
        returns (bytes32, bytes memory)
    {
        // Prepare the inputs
        BtcTxIn[] memory btcInputs = new BtcTxIn[](1);
        btcInputs[0] = BtcTxIn({
            txId: _acceptPegInTx,
            vout: Constants.VOUT_INDEX_TAPTREE,
            scriptSig: bytes(""),
            sequence: Constants.SEQUENCE
        });

        // Add inputs previous output data
        PrevoutData[] memory prevoutDatas = new PrevoutData[](1);
        prevoutDatas[0] = _prevoutData;

        // Prepare the outputs, user and speed up
        BtcTxOut[] memory btcOutputs = new BtcTxOut[](2);

        // Calculate fee and speedUpAmount from amount
        // TODO: atm is returning hardcoded values, should be calculated
        (uint64 fee, uint64 speedUpAmount) = BtcHelper.calculateFeeAndSpeedUp(_prevoutData.value);

        // User pegout
        bytes memory scriptPubKey = BtcScriptParser.getP2WPKHScript(_usrPubKey);
        btcOutputs[0] = BtcTxOut({amount: _prevoutData.value - fee - speedUpAmount, scriptPubKey: scriptPubKey});

        // Speed up
        btcOutputs[1] = BtcTxOut({amount: speedUpAmount, scriptPubKey: scriptPubKey});

        // Prepare Btc Transaction
        BtcTransaction memory pegOutTx = BtcTransaction({
            version: Constants.BTC_TX_VERSION,
            locktime: Constants.LOCKTIME,
            inputs: btcInputs,
            outputs: btcOutputs
        });
        // Return the tagged hash and the encoded data before hashing
        return taprootSignatureHash(Constants.SIGHASH_ALL, prevoutDatas, pegOutTx);
    }

    /// @dev Returns Signature Hash. The signature hash is the actual "message" that we sign when creating the signature.
    /// @dev It's a tagged hash of the common signature message, along with a sighash epoch prefix and the optional extension:
    /// @dev https://learnmeabitcoin.com/technical/upgrades/taproot/#signature-hash
    function taprootSignatureHash(uint8 _hashType, PrevoutData[] memory _prevoutDatas, BtcTransaction memory _btcTx)
        internal
        pure
        returns (bytes32, bytes memory)
    {
        // Concatenate all the data
        bytes memory encodedData = BtcTxEncoder.encodeCommonSignatureMessage(_hashType, _prevoutDatas, _btcTx);

        // Return the tagged hash and the encoded data before hashing
        return (BtcTaproot.getSighash(encodedData), encodedData);
    }
}
