// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
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
    /// @param _timelockBlocks The timelock blocks for the Bitcoin transaction
    /// @param _rskDestinationAddress The RSK address that will receive the RBTC
    /// @param _value The amount in satoshis for the peg-in request
    /// @param _btcReimbursementPubKey The user's Bitcoin public key for reimbursement (x-only)
    /// @param _committeePubKey The committee's public key for the Taproot address
    /// @return temporaryPeginAddress The generated temporary Bitcoin address for deposit
    function getTemporaryPeginAddress(
        uint32 _timelockBlocks,
        address _rskDestinationAddress,
        uint64 _value,
        bytes32 _btcReimbursementPubKey,
        bytes memory _committeePubKey
    ) external view returns (string memory temporaryPeginAddress) {
        _validateRequestPeginInputs(
            _timelockBlocks, _btcReimbursementPubKey, _committeePubKey, _rskDestinationAddress, _value
        );

        bytes32 tweakedPublicKey = getRequestPeginTweakedPublicKey(
            _timelockBlocks, _rskDestinationAddress, _value, _btcReimbursementPubKey, _committeePubKey
        );

        return Bech32m.encodeTaprootAddress(abi.encodePacked(tweakedPublicKey), network);
    }

    /// @dev Generates the RequestPegin Taproot output script pub key with both key spend and script spend paths
    function getRequestPeginTweakedPublicKey(
        uint32 _timelockBlocks,
        address _rskDestinationAddress,
        uint64 _value,
        bytes32 _btcReimbursementPubKey,
        bytes memory _committeePubKey
    ) internal pure returns (bytes32) {
        bytes memory timelockScript = BtcScriptParser.getTimelockScript(_timelockBlocks, _btcReimbursementPubKey);
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
        uint32 _timelockBlocks,
        bytes32 _btcReimbursementPubKey,
        bytes memory _committeePubKey,
        address _rskDestinationAddress,
        uint64 _value
    ) internal pure {
        if (_timelockBlocks == 0) {
            revert InvalidTimelockBlocks(_timelockBlocks);
        }
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
    /// @param _timelockBlocks The timelock blocks for the Bitcoin transaction
    /// @param _rskDestinationAddress Address that will get the RBTC
    /// @param _streamDenomination The expected amount in satoshis
    /// @param _btcReimbursementPubKey The user's public key (x-only, 32 bytes)
    /// @param _committeePubKey The committee's public key (x-only, 32 bytes)
    /// @param _p2trOut The P2TR output of the peg-in request
    function validateRequestPeginP2TROutput(
        uint32 _timelockBlocks,
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
            _timelockBlocks, _btcReimbursementPubKey, _committeePubKey, _rskDestinationAddress, _streamDenomination
        );
        bytes memory p2trScriptPubKey = getRequestPeginP2TRScriptPub(
            _timelockBlocks, _rskDestinationAddress, _streamDenomination, _btcReimbursementPubKey, _committeePubKey
        );
        _compareOutputPubKey(_p2trOut.scriptPubKey, p2trScriptPubKey);
    }

    /// @notice Validates the enabler output in a request peg-in transaction
    /// @param _committeePubKey The committee's public key
    /// @param _disputeKeys The dispute keys (covenant public keys) for the committee
    /// @param _enablerOut The enabler output to validate
    function validateRequestPeginEnablerOutput(
        bytes memory _committeePubKey,
        bytes32[] memory _disputeKeys,
        BtcTxOut calldata _enablerOut
    ) external view onlyPeginManager {
        // Validate that the amount matches the expected enabler amount
        if (_enablerOut.amount != Constants.ENABLER_AMOUNT) {
            revert InvalidOutputAmount(_enablerOut.amount, Constants.ENABLER_AMOUNT);
        }

        // Generate expected enabler output script pub key
        // TODO: this could be optimized by keeping the result saved in storage per committee/packet
        bytes memory expectedScriptPubKey = getEnablerOutputP2TRScriptPub(_committeePubKey, _disputeKeys);

        // Validate the script pub key matches
        _compareOutputPubKey(_enablerOut.scriptPubKey, expectedScriptPubKey);
    }

    /// @notice Generates the RequestPegin Taproot output script pub key with both key spend and script spend paths
    /// @param _timelockBlocks The timelock blocks for the Bitcoin transaction
    /// @param _rskDestinationAddress The RSK address that will receive the RBTC
    /// @param _value The amount in satoshis for the peg-in request
    /// @param _btcReimbursementPubKey The user's Bitcoin public key for reimbursement (x-only)
    /// @param _committeePubKey The committee's public key for the Taproot address (x-only)
    /// @return The P2TR script pub key bytes
    function getRequestPeginP2TRScriptPub(
        uint32 _timelockBlocks,
        address _rskDestinationAddress,
        uint64 _value,
        bytes32 _btcReimbursementPubKey,
        bytes memory _committeePubKey
    ) internal pure returns (bytes memory) {
        bytes32 tweakedPublicKey = getRequestPeginTweakedPublicKey(
            _timelockBlocks, _rskDestinationAddress, _value, _btcReimbursementPubKey, _committeePubKey
        );
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

    function validatePegoutIdOutput(BtcTxOut calldata _pegoutIdOutput, bytes32 _pegoutId) external pure {
        bytes memory pegoutIdScript = BtcScriptParser.getPegoutIdScript(_pegoutId);

        _compareOutputPubKey(_pegoutIdOutput.scriptPubKey, pegoutIdScript);
    }

    // ========================== Peg In Accept ==========================
    /// @notice Gets the signature hash for a peg-in accept transaction
    /// @param _committeePubKey The committee's public key (x-only)
    /// @param _userXOnlyPubKey The user's public key (x-only) for speed-up output
    /// @param _registerPeginTx The hash of the register peg-in transaction
    /// @param _prevoutDatas Array of prevout data for all inputs being spent (taptree + enabler outputs)
    /// @param _operatorDisputeKeys The dispute keys (covenant public keys) for OPERATOR members only
    /// @return The transaction id, signature hash, and signature message
    function getAcceptPeginSignatureHash(
        bytes memory _committeePubKey,
        bytes32 _userXOnlyPubKey,
        bytes32 _registerPeginTx,
        PrevoutData[] memory _prevoutDatas,
        bytes32[] memory _operatorDisputeKeys
    ) external view onlyPeginManager returns (BitcoinSignatureData memory) {
        // Prepare the inputs
        BtcTxIn[] memory btcInputs = new BtcTxIn[](Constants.ACCEPT_PEGIN_INPUT_COUNT);
        btcInputs[Constants.ACCEPT_PEGIN_VIN_TAPTREE] = BtcTxIn({
            txId: _registerPeginTx,
            vout: Constants.REQUEST_PEGIN_VOUT_TAPTREE,
            scriptSig: bytes(""),
            sequence: Constants.SEQUENCE
        });
        // Add second input for enabler output
        btcInputs[Constants.ACCEPT_PEGIN_VIN_ENABLER] = BtcTxIn({
            txId: _registerPeginTx,
            vout: Constants.REQUEST_PEGIN_VOUT_ENABLER,
            scriptSig: bytes(""),
            sequence: Constants.SEQUENCE
        });

        // Prepare the outputs: committee taptree, enabler, and speed-up
        BtcTxOut[] memory btcOutputs = new BtcTxOut[](Constants.ACCEPT_PEGIN_OUTPUT_COUNT);

        // Calculate fee and speedUpAmount from amount
        // TODO: atm is returning hardcoded values, should be calculated
        (uint64 fee, uint64 speedUpAmount) = BtcHelper.calculateFeeAndSpeedUp();

        // Committee accept pegin (using value from first input - request pegin taptree output)
        // Deduct fee, SPEED_UP_AMOUNT, and ENABLER_AMOUNT for the enabler output
        bytes memory scriptPubKey = getAcceptPeginP2TRScriptPub(_committeePubKey);
        btcOutputs[Constants.ACCEPT_PEGIN_VOUT_TAPTREE] = BtcTxOut({
            amount: _prevoutDatas[Constants.REQUEST_PEGIN_VOUT_TAPTREE].value - fee - speedUpAmount
                - Constants.ENABLER_AMOUNT,
            scriptPubKey: scriptPubKey
        });

        // Enabler output with operator-only dispute keys
        bytes memory enablerScriptPubKey = getEnablerOutputP2TRScriptPub(_committeePubKey, _operatorDisputeKeys);
        btcOutputs[Constants.ACCEPT_PEGIN_VOUT_ENABLER] =
            BtcTxOut({amount: Constants.ENABLER_AMOUNT, scriptPubKey: enablerScriptPubKey});

        // Speed up
        bytes memory speedUpScriptPubKey = getSpeedUpScriptPub(_userXOnlyPubKey);
        btcOutputs[Constants.ACCEPT_PEGIN_VOUT_SPEED_UP] =
            BtcTxOut({amount: speedUpAmount, scriptPubKey: speedUpScriptPubKey});

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
            taprootSignatureHash(Constants.SIGHASH_ALL, _prevoutDatas, acceptPeginTx);
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

    function _getVerifyKeyScript(bytes32 _disputeKey) internal pure returns (bytes memory) {
        return abi.encodePacked(OpCodes.OP_PUSHBYTES_32, _disputeKey, OpCodes.OP_CHECKSIG);
    }

    function _getVerifyKeyLeaves(bytes32[] memory _keys) internal pure returns (bytes32[] memory) {
        bytes32[] memory leaves = new bytes32[](_keys.length);
        for (uint256 i = 0; i < _keys.length; i++) {
            bytes memory script = _getVerifyKeyScript(_keys[i]);
            leaves[i] = BtcTaproot.getLeaf(script);
        }
        return leaves;
    }

    /// @notice Builds a balanced Taproot merkle tree from leaves
    /// @dev Implements the same balanced tree algorithm as Bitcoin's TaprootBuilder
    /// @param _leaves Array of leaf hashes to build the tree from
    /// @return The merkle root hash
    function _buildMerkleTreeFromLeaves(bytes32[] memory _leaves) internal pure returns (bytes32) {
        uint256 scriptsCount = _leaves.length;

        // For empty scripts, return zero
        if (scriptsCount == 0) {
            return bytes32(0);
        }

        // For a single script, return it directly (it becomes the merkle root)
        if (scriptsCount == 1) {
            return _leaves[0];
        }

        // For multiple scripts, build a balanced tree
        // Calculate the minimum depth needed to hold all scripts
        // min_depth = floor(log2(scriptsCount - 1))
        uint256 minDepth = Math.log2(scriptsCount - 1);

        // Calculate how many nodes go at the minimum depth vs minimum depth + 1
        uint256 totalSlots = 1 << (minDepth + 1); // 2^(minDepth + 1)
        uint256 nodesAtMinDepth = totalSlots - scriptsCount;

        // Build array to hold nodes at each depth
        // Max depth is minDepth + 1, so we need minDepth + 2 levels
        bytes32[][] memory levels = new bytes32[][](minDepth + 2);

        // Initialize level arrays
        for (uint256 d = 0; d <= minDepth + 1; d++) {
            levels[d] = new bytes32[](scriptsCount); // Allocate max possible size
        }

        uint256[] memory levelSizes = new uint256[](minDepth + 2);

        // Add leaves at minimum depth
        for (uint256 i = 0; i < nodesAtMinDepth; i++) {
            levels[minDepth][levelSizes[minDepth]++] = _leaves[i];
        }

        // Add remaining leaves at minimum depth + 1
        for (uint256 i = nodesAtMinDepth; i < scriptsCount; i++) {
            levels[minDepth + 1][levelSizes[minDepth + 1]++] = _leaves[i];
        }

        // Build the tree bottom-up
        for (uint256 depth = minDepth + 1; depth > 0; depth--) {
            uint256 currentLevelSize = levelSizes[depth];
            if (currentLevelSize == 0) continue;

            // Pair up nodes at current depth and create parents
            for (uint256 i = 0; i < currentLevelSize; i += 2) {
                if (i + 1 < currentLevelSize) {
                    // Pair of nodes - combine them
                    bytes32 parent = BtcTaproot.getBranch(levels[depth][i], levels[depth][i + 1]);
                    levels[depth - 1][levelSizes[depth - 1]++] = parent;
                } else {
                    // Odd node - promote to next level
                    levels[depth - 1][levelSizes[depth - 1]++] = levels[depth][i];
                }
            }
        }

        // The root is the single node at level 0
        return levels[0][0];
    }

    function _getEnablerOutputTweakedPublicKey(bytes memory _committeePubKey, bytes32[] memory _disputeKeys)
        internal
        pure
        returns (bytes32)
    {
        // Extract x-coordinate from compressed public key
        bytes32 committeePubKeyX;
        // slither-disable-next-line assembly
        assembly {
            committeePubKeyX := mload(add(_committeePubKey, 33))
        }

        // Create script leaves for each dispute key
        bytes32[] memory leaves = _getVerifyKeyLeaves(_disputeKeys);

        bytes32 merkleRoot = _buildMerkleTreeFromLeaves(leaves);

        bytes32 tweak = BtcTaproot.getTweak(abi.encodePacked(committeePubKeyX, merkleRoot));
        bytes32 tweakedPublicKey = BtcTaproot.getTweakedPublicKey(committeePubKeyX, tweak);

        return tweakedPublicKey;
    }

    /// @notice Generates the enabler output P2TR script pub key
    /// @param _committeePubKey The committee's aggregated public key (33 bytes compressed)
    /// @param _disputeKeys Array of dispute keys for committee members (x-only, 32 bytes each)
    /// @return The P2TR script pub key bytes
    function getEnablerOutputP2TRScriptPub(bytes memory _committeePubKey, bytes32[] memory _disputeKeys)
        public
        pure
        returns (bytes memory)
    {
        bytes32 tweakedPublicKey = _getEnablerOutputTweakedPublicKey(_committeePubKey, _disputeKeys);
        return BtcTaproot.getP2TRScriptPubKey(tweakedPublicKey);
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
    /// @param _prevoutDatas Array of prevout data for all inputs being spent (taptree + enabler outputs)
    /// @return bytes32 The txid, bytes32 the signature hash and bytes signature message
    function getPegoutTxData(bytes memory _userPubKey, bytes32 _acceptPeginTx, PrevoutData[] memory _prevoutDatas)
        external
        pure
        returns (BitcoinSignatureData memory)
    {
        // Prepare the inputs: taptree output and enabler output
        BtcTxIn[] memory btcInputs = new BtcTxIn[](Constants.PEGOUT_INPUT_COUNT);
        btcInputs[Constants.PEGOUT_VIN_TAPTREE] = BtcTxIn({
            txId: _acceptPeginTx,
            vout: Constants.ACCEPT_PEGIN_VOUT_TAPTREE,
            scriptSig: bytes(""),
            sequence: Constants.SEQUENCE
        });
        // Add second input for enabler output
        btcInputs[Constants.PEGOUT_VIN_ENABLER] = BtcTxIn({
            txId: _acceptPeginTx,
            vout: Constants.ACCEPT_PEGIN_VOUT_ENABLER,
            scriptSig: bytes(""),
            sequence: Constants.SEQUENCE
        });

        // Prepare the outputs, user and speed up
        BtcTxOut[] memory btcOutputs = new BtcTxOut[](Constants.PEGOUT_OUTPUT_COUNT);

        // Calculate fee and speedUpAmount from amount
        // TODO: atm is returning hardcoded values, should be calculated
        (uint64 fee, uint64 speedUpAmount) = BtcHelper.calculateFeeAndSpeedUp();

        // User pegout (using value from first input - accept pegin taptree output)
        bytes memory scriptPubKey = BtcScriptParser.getP2WPKHScript(_userPubKey);
        btcOutputs[Constants.PEGOUT_VOUT_USER] = BtcTxOut({
            amount: _prevoutDatas[Constants.ACCEPT_PEGIN_VOUT_TAPTREE].value - fee - speedUpAmount,
            scriptPubKey: scriptPubKey
        });

        // Speed up
        btcOutputs[Constants.PEGOUT_VOUT_SPEED_UP] = BtcTxOut({amount: speedUpAmount, scriptPubKey: scriptPubKey});

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
            taprootSignatureHash(Constants.SIGHASH_ALL, _prevoutDatas, pegoutTx);
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
