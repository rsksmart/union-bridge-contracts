// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {BaseProxy} from "./BaseProxy.sol";
import {
    PrevoutData,
    BtcTransaction,
    BtcTxIn,
    BtcTxOut,
    IBitcoinManager,
    BitcoinSignatureData
} from "./interfaces/IBitcoinManager.sol";
import {IPeginManager} from "./interfaces/IPeginManager.sol";
import {BytesHelper} from "./libraries/BytesHelper.sol";
import {BtcHelper} from "./libraries/BtcHelper.sol";
import {BtcTxEncoder} from "./libraries/BtcTxEncoder.sol";
import {BtcScriptParser} from "./libraries/BtcScriptParser.sol";
import {BtcTaproot} from "./libraries/BtcTaproot.sol";
import {Bech32m} from "src/libraries/Bech32m.sol";
import {OpCodes} from "./libraries/OpCodes.sol";
import {BtcNetwork} from "./libraries/Network.sol";
import {Constants} from "./libraries/Constants.sol";

/// @title Bitcoin Manager
/// @notice Manages Bitcoin addresses and scripts for the union bridge
/// @dev Provides functionality for creating and validating Bitcoin transactions, addresses, and scripts
/// @dev Handles peg-in requests, peg-in acceptance, speed-up transactions, and peg-out operations
contract BitcoinManager is IBitcoinManager, Initializable, BaseProxy {
    /// @notice The Bitcoin network this contract operates on (mainnet, testnet, or regtest)
    /// @dev Determines the address format and network-specific parameters
    BtcNetwork public network;

    /// @notice Peg manager contract for peg-in/peg-out coordination
    IPeginManager peginManager;

    /// @notice Initializes the BitcoinManager contract
    /// @dev Sets up the Bitcoin network and initial owner
    /// @dev Can only be called once during contract deployment
    /// @param _initialOwner The address that will be set as the initial owner
    /// @param _network The Bitcoin network to operate on
    function initialize(address _initialOwner, BtcNetwork _network) public initializer {
        network = _network;
        __BaseProxy_init(_initialOwner);
    }

    /// @notice Sets the Peg Manager contract address
    /// @dev Only callable by the contract owner
    /// @param _peginManager The address of the Pegin Manager contract
    function setPeginManager(IPeginManager _peginManager) external onlyOwner {
        if (address(_peginManager) == address(0)) {
            revert InvalidZeroAddress();
        }
        peginManager = _peginManager;
        emit PeginManagerUpdated(address(_peginManager));
    }

    /// @notice Converts a Bitcoin transaction to raw hex format and calculates its hash
    /// @dev Uses Bitcoin format encoding and then applies hash256 to get the transaction id
    /// @param _btcTx The Bitcoin transaction to hash
    /// @return The transaction id in bytes32 format
    function getBtcTxid(BtcTransaction calldata _btcTx) external pure returns (bytes32) {
        return _getBtcTxid(_btcTx);
    }

    function _getBtcTxid(BtcTransaction memory _btcTx) internal pure returns (bytes32) {
        return BtcHelper.hash256(BtcTxEncoder.encodeTx(_btcTx));
    }

    // ========================== Peg In Request ==========================
    /// @notice Generates a temporary peg-in address for a peg-in request
    /// @dev Creates a Taproot address with both key spend and script spend paths
    /// @param _rskDestinationAddress The RSK address that will receive the RBTC
    /// @param _value The amount in satoshis for the peg-in request
    /// @param _btcReimbursementPubKey The user's Bitcoin public key for reimbursement (x-only)
    /// @param _committeePubKey The committee's public key for the Taproot address
    /// @return temporaryPeginAddress The generated temporary Bitcoin address for deposit
    function getTemporaryPeginAddress(
        address _rskDestinationAddress,
        uint64 _value,
        bytes32 _btcReimbursementPubKey,
        bytes memory _committeePubKey
    ) external view returns (string memory temporaryPeginAddress) {
        _validateRequestPeginInputs(_btcReimbursementPubKey, _committeePubKey, _rskDestinationAddress, _value);

        bytes32 tweakedPublicKey =
            getRequestPeginTweakedPublicKey(_rskDestinationAddress, _value, _btcReimbursementPubKey, _committeePubKey);

        return Bech32m.encodeTaprootAddress(abi.encodePacked(tweakedPublicKey), network);
    }

    /// @dev Generates the RequestPegin Taproot output script pub key with both key spend and script spend paths
    function getRequestPeginTweakedPublicKey(
        address _rskDestinationAddress,
        uint64 _value,
        bytes32 _btcReimbursementPubKey,
        bytes memory _committeePubKey
    ) internal pure returns (bytes32) {
        bytes memory timelockScript =
            BtcScriptParser.getTimelockScript(Constants.TIMELOCK_BLOCKS, _btcReimbursementPubKey);
        bytes32 timelockLeaf = BtcTaproot.getLeaf(timelockScript);

        bytes memory extraDataScript =
            abi.encodePacked(OpCodes.OP_RETURN, OpCodes.OP_PUSHBYTES_28, _rskDestinationAddress, _value);
        bytes32 extraDataLeaf = BtcTaproot.getLeaf(extraDataScript);

        bytes32 merkleRoot = BtcTaproot.getBranch(timelockLeaf, extraDataLeaf);

        // Extract x-coordinate from compressed public key (skip first byte which is prefix)
        // Assembly is required here for BIP340 X-only public key extraction from the 33-byte compressed format.
        // BIP340 specifies Schnorr signatures use only the x-coordinate, stored at bytes 1-32 (skipping the prefix byte).
        bytes32 committeePubKeyX;
        // slither-disable-next-line assembly
        assembly {
            committeePubKeyX := mload(add(_committeePubKey, 33))
        }

        bytes32 tweak = BtcTaproot.getTweak(abi.encodePacked(committeePubKeyX, merkleRoot));
        bytes32 tweakedPublicKey = BtcTaproot.getTweakedPublicKey(committeePubKeyX, tweak);

        return tweakedPublicKey;
    }

    /// @dev Validates the inputs for a peg-in request
    function _validateRequestPeginInputs(
        bytes32 _btcReimbursementPubKey,
        bytes memory _committeePubKey,
        address _rskDestinationAddress,
        uint64 _value
    ) internal pure {
        if (_btcReimbursementPubKey == bytes32(0)) {
            revert InvalidPublicKey(_btcReimbursementPubKey);
        }
        if (_committeePubKey.length != 33) {
            revert InvalidCommitteePublicKeyLength(_committeePubKey.length, 33);
        }
        if (keccak256(_committeePubKey) == keccak256(new bytes(33))) {
            revert InvalidCommitteePublicKeyZero();
        }
        if (_rskDestinationAddress == address(0)) {
            revert InvalidAddress(_rskDestinationAddress);
        }
        if (_value == 0) {
            revert InvalidInputAmount(_value);
        }
    }

    /// @notice Extracts data from a peg-in OP_RETURN output
    /// @dev Expected OP_RETURN format:
    /// @dev [OP_RETURN (1 byte)]
    /// @dev [OP_PUSHBYTES_69 (1 byte)]
    /// @dev [RSK_PEGIN (9 bytes)]
    /// @dev [packet number (8 bytes)]
    /// @dev [rsk destination address (20 bytes)]
    /// @dev [reimbursement public key (32 bytes)]
    /// @dev Total expected size: 71 bytes
    /// @param _opReturnOut The OP_RETURN output to parse
    /// @return The packet number, RSK destination address, and Bitcoin reimbursement public key
    function getPeginOpReturnData(BtcTxOut calldata _opReturnOut) external pure returns (uint64, address, bytes32) {
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
    /// @param _rskDestinationAddress Address that will get the RBTC
    /// @param _streamDenomination The expected amount in satoshis
    /// @param _btcReimbursementPubKey The user's public key (x-only, 32 bytes)
    /// @param _committeePubKey The committee's public key (x-only, 32 bytes)
    /// @param _p2trOut The P2TR output of the peg-in request
    function validateRequestPeginP2TROutput(
        address _rskDestinationAddress,
        uint64 _streamDenomination,
        bytes32 _btcReimbursementPubKey,
        bytes memory _committeePubKey,
        BtcTxOut calldata _p2trOut
    ) external view onlyPeginManager {
        // Validate that the amount is enough for the stream
        if (_p2trOut.amount < _streamDenomination) {
            revert InvalidOutputAmount(_p2trOut.amount, _streamDenomination);
        }
        _validateRequestPeginInputs(
            _btcReimbursementPubKey, _committeePubKey, _rskDestinationAddress, _streamDenomination
        );
        bytes memory p2trScriptPubKey = getRequestPeginP2TRScriptPub(
            _rskDestinationAddress, _streamDenomination, _btcReimbursementPubKey, _committeePubKey
        );
        _compareOutputPubKey(_p2trOut.scriptPubKey, p2trScriptPubKey);
    }

    /// @notice Generates the RequestPegin Taproot output script pub key with both key spend and script spend paths
    /// @param _rskDestinationAddress The RSK address that will receive the RBTC
    /// @param _value The amount in satoshis for the peg-in request
    /// @param _btcReimbursementPubKey The user's Bitcoin public key for reimbursement (x-only)
    /// @param _committeePubKey The committee's public key for the Taproot address (x-only)
    /// @return The P2TR script pub key bytes
    function getRequestPeginP2TRScriptPub(
        address _rskDestinationAddress,
        uint64 _value,
        bytes32 _btcReimbursementPubKey,
        bytes memory _committeePubKey
    ) internal pure returns (bytes memory) {
        bytes32 tweakedPublicKey =
            getRequestPeginTweakedPublicKey(_rskDestinationAddress, _value, _btcReimbursementPubKey, _committeePubKey);
        return BtcTaproot.getP2TRScriptPubKey(tweakedPublicKey);
    }

    function _compareOutputPubKey(bytes memory outputPubKey, bytes memory expectedPubKey) internal pure {
        // Validate that the output script matches the expected P2WPKH script
        if (!BytesHelper.compare(outputPubKey, expectedPubKey)) {
            revert IncorrectOutputScript(outputPubKey, expectedPubKey);
        }
    }

    /// @notice Validates a peg-out user output against the expected P2WPKH script
    /// @param _userOutput The Bitcoin transaction output to validate
    /// @param _userPubKey The user's public key to generate the expected script
    function validatePegoutUserOutput(BtcTxOut calldata _userOutput, bytes memory _userPubKey) external pure {
        bytes memory expectedScriptPubKey = BtcScriptParser.getP2WPKHScript(_userPubKey);

        _compareOutputPubKey(_userOutput.scriptPubKey, expectedScriptPubKey);
    }

    function validatePegoutMemberOutput(BtcTxOut calldata _userOutput, bytes32 _memberPubKey) external pure {
        bytes memory expectedScriptPubKey =
            BtcScriptParser.getP2WPKHScript(BtcHelper.pubKeyXonlyToCompact(_memberPubKey));

        _compareOutputPubKey(_userOutput.scriptPubKey, expectedScriptPubKey);
    }

    // ========================== Peg In Accept ==========================
    /// @notice Gets the signature hash for a peg-in accept transaction
    /// @param _committeePubKey The committee's public key (x-only)
    /// @param _userXOnlyPubKey The user's public key (x-only) for speed-up output
    /// @param _registerPeginTx The hash of the register peg-in transaction
    /// @param _prevoutData The previous output data for the input
    /// @return The transaction id, signature hash, and signature message
    function getAcceptPeginSignatureHash(
        bytes memory _committeePubKey,
        bytes32 _userXOnlyPubKey,
        bytes32 _registerPeginTx,
        PrevoutData memory _prevoutData
    ) external view onlyPeginManager returns (BitcoinSignatureData memory) {
        // Prepare the inputs
        BtcTxIn[] memory btcInputs = new BtcTxIn[](1);
        btcInputs[0] = BtcTxIn({
            txId: _registerPeginTx,
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
        (uint64 fee, uint64 speedUpAmount) = BtcHelper.calculateFeeAndSpeedUp();

        // Committee accept pegin
        bytes memory scriptPubKey = getAcceptPeginP2TRScriptPub(_committeePubKey);
        btcOutputs[0] = BtcTxOut({amount: _prevoutData.value - fee - speedUpAmount, scriptPubKey: scriptPubKey});

        // Speed up
        bytes memory speedUpScriptPubKey = getSpeedUpScriptPub(_userXOnlyPubKey);
        btcOutputs[1] = BtcTxOut({amount: speedUpAmount, scriptPubKey: speedUpScriptPubKey});

        // Prepare Btc Transaction
        BtcTransaction memory acceptPeginTx = BtcTransaction({
            version: Constants.BTC_TX_VERSION,
            locktime: Constants.LOCKTIME,
            inputs: btcInputs,
            outputs: btcOutputs
        });
        bytes32 txid = _getBtcTxid(acceptPeginTx);
        // Return the tagged hash and the encoded data before hashing
        (bytes32 acceptPeginSignatureHash, bytes memory acceptPeginSignatureMessage) =
            taprootSignatureHash(Constants.SIGHASH_ALL, prevoutDatas, acceptPeginTx);
        return BitcoinSignatureData({
            tx: acceptPeginTx,
            txid: txid,
            signatureHash: acceptPeginSignatureHash,
            signatureMessage: acceptPeginSignatureMessage
        });
    }

    /// @dev Generates the Accept Pegin Taproot output script pub key with both key spend and script spend paths
    function getAcceptPeginTweakedPublicKey(bytes memory _committeePubKey) internal pure returns (bytes32) {
        // Extract x-coordinate from compressed public key (skip first byte which is prefix)
        // Assembly is required here for BIP340 X-only public key extraction from the 33-byte compressed format.
        // BIP340 specifies Schnorr signatures use only the x-coordinate, stored at bytes 1-32 (skipping the prefix byte).
        bytes32 committeePubKeyX;
        // slither-disable-next-line assembly
        assembly {
            committeePubKeyX := mload(add(_committeePubKey, 33))
        }

        // Currently we only consider the key spend path (user take)
        bytes32 tweak = BtcTaproot.getTweak(abi.encodePacked(committeePubKeyX));
        bytes32 tweakedPublicKey = BtcTaproot.getTweakedPublicKey(committeePubKeyX, tweak);

        return tweakedPublicKey;
    }

    /// @notice Generates the Accept Pegin Taproot output script pub key with both key spend and script spend paths
    /// @param _committeePubKey The committee's public key (x-only)
    /// @return The P2TR script pub key bytes
    function getAcceptPeginP2TRScriptPub(bytes memory _committeePubKey) internal pure returns (bytes memory) {
        bytes32 tweakedPublicKey = getAcceptPeginTweakedPublicKey(_committeePubKey);
        return BtcTaproot.getP2TRScriptPubKey(tweakedPublicKey);
    }

    // ========================== Peg In Speed Up ==========================
    /// @notice Validates the speed-up output
    /// @param _pubKey The public key for the speed-up output (x-only)
    /// @param _speedUpOut The speed-up output to validate
    function validateSpeedUpOutput(bytes32 _pubKey, BtcTxOut calldata _speedUpOut) external pure {
        if (_speedUpOut.amount < Constants.SPEED_UP_AMOUNT) {
            revert InvalidValue(_speedUpOut.amount, Constants.SPEED_UP_AMOUNT);
        }
        bytes memory p2wpkhScriptPubKey = getSpeedUpScriptPub(_pubKey);
        _compareOutputPubKey(_speedUpOut.scriptPubKey, p2wpkhScriptPubKey);
    }

    /// @notice Generates the speed-up script pub key
    /// @param _pubKey The public key for the speed-up output (x-only)
    /// @return The P2WPKH script pub key bytes
    function getSpeedUpScriptPub(bytes32 _pubKey) public pure returns (bytes memory) {
        // TODO change this to use P2WPSH with OP_1 so anyone can send the speed up
        // this should change at the same time as in the protocol builder
        return BtcScriptParser.getP2WPKHScript(BtcHelper.pubKeyXonlyToCompact(_pubKey));
    }

    // ========================== Peg Out Signature Hash ==========================
    /// @notice Generates the signature hash for a peg-out transaction
    /// @param _userPubKey The user's public key for the peg-out
    /// @param _acceptPeginTx The hash of the accept peg-in transaction
    /// @param _prevoutData The previous output data for the input
    /// @return bytes32 The txid, bytes32 the signature hash and bytes signature message
    function getPegoutTxData(bytes memory _userPubKey, bytes32 _acceptPeginTx, PrevoutData memory _prevoutData)
        external
        pure
        returns (BitcoinSignatureData memory)
    {
        // Prepare the inputs
        BtcTxIn[] memory btcInputs = new BtcTxIn[](1);
        btcInputs[0] = BtcTxIn({
            txId: _acceptPeginTx,
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
        (uint64 fee, uint64 speedUpAmount) = BtcHelper.calculateFeeAndSpeedUp();

        // User pegout
        bytes memory scriptPubKey = BtcScriptParser.getP2WPKHScript(_userPubKey);
        btcOutputs[0] = BtcTxOut({amount: _prevoutData.value - fee - speedUpAmount, scriptPubKey: scriptPubKey});

        // Speed up
        btcOutputs[1] = BtcTxOut({amount: speedUpAmount, scriptPubKey: scriptPubKey});

        // Prepare Btc Transaction
        BtcTransaction memory pegoutTx = BtcTransaction({
            version: Constants.BTC_TX_VERSION,
            locktime: Constants.LOCKTIME,
            inputs: btcInputs,
            outputs: btcOutputs
        });
        // Return the tagged hash and the encoded data before hashing

        bytes32 txid = _getBtcTxid(pegoutTx);
        (bytes32 pegoutSignatureHash, bytes memory pegoutSignatureMessage) =
            taprootSignatureHash(Constants.SIGHASH_ALL, prevoutDatas, pegoutTx);
        return BitcoinSignatureData({
            tx: pegoutTx,
            txid: txid,
            signatureHash: pegoutSignatureHash,
            signatureMessage: pegoutSignatureMessage
        });
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

    // ===================== Modifiers =====================

    /// @notice Modifier to restrict access to the PeginManager contract
    modifier onlyPeginManager() {
        _onlyPeginManager(_msgSender());
        _;
    }

    function _onlyPeginManager(address _account) internal view {
        if (address(peginManager) != _account) {
            revert UnauthorizedAccount(_account);
        }
    }
}
