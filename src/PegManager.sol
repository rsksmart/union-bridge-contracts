// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import "forge-std/console.sol";
import {BaseProxy} from "./BaseProxy.sol";
import {Committee, ICommitteeRegistry} from "./interfaces/ICommitteeRegistry.sol";
import {BtcTransaction, BtcTxOut, IBitcoinManager} from "./interfaces/IBitcoinManager.sol";
import {
    BtcTxSPVProof,
    StreamPosition,
    RequestPegInTempInfo,
    PegStatus,
    PrevoutData,
    IPegManager
} from "./interfaces/IPegManager.sol";
import {Slot, Stream, Packet, SlotState, StreamManager} from "./StreamManager.sol";
import {ProofValidator} from "./ProofValidator.sol";
import {BtcHelper} from "./libraries/BtcHelper.sol";
import {BtcScriptParser} from "./libraries/BtcScriptParser.sol";
import {BtcTaproot} from "./libraries/BtcTaproot.sol";
import {OpCodes} from "./libraries/OpCodes.sol";

/// @title PegManager
/// @notice Manages peg-in and peg-out operations between Bitcoin and Rootstock
contract PegManager is IPegManager, StreamManager, ProofValidator, BaseProxy {
    ICommitteeRegistry public committeeRegistry;
    IBitcoinManager public bitcoinManager;
    uint64 constant VOUT_INDEX_TAPTREE = 0;
    uint64 constant VOUT_INDEX_SPEED_UP = 1;

    // Request PegIn Tx Hash => Stream Position (streamId, packetNumber, slotId, pegStatus)
    mapping(bytes32 btcRequestPegInTxHash => StreamPosition streamPosition) internal pegInRequests;
    // Request PegIn Tx Hash => PegIn Temp Info (value, rskDestinationAddress, btcReimbursementPubKey)
    mapping(bytes32 btcRequestPegInTxHash => RequestPegInTempInfo tempInfo) internal pegInsTempInfo;
    // key = keccak256(abi.encodePacked(_bitcoinUserAddress, _amount))
    mapping(bytes32 key => bytes32 pegOutTxHash) internal pegOutTxHashes;

    function initialize(
        address _initialOwner,
        address payable _bridgeAddress,
        ICommitteeRegistry _committeeRegistry,
        IBitcoinManager _bitcoinManager,
        uint64[] memory _denominations
    ) public virtual initializer {
        committeeRegistry = _committeeRegistry;
        bitcoinManager = _bitcoinManager;
        StreamManager.initialize(_denominations);
        __ProofValidator_init(_bridgeAddress);
        __BaseProxy_init(_initialOwner);
    }

    function getPegInRequest(bytes32 btcTxHash) external view returns (StreamPosition memory) {
        return pegInRequests[btcTxHash];
    }

    function getRequestPegInTempInfo(bytes32 btcTxHash) external view returns (RequestPegInTempInfo memory) {
        return pegInsTempInfo[btcTxHash];
    }

    function getTemporaryPegInAddress(address _rootstockDepositAddress, uint64 _value, bytes32 _btcReimbursementPubKey)
        external
        view
        returns (string memory bitcoinDepositAddress)
    {
        // Get the stream for this value
        Stream memory stream = getStream(_value);

        // Get the current packet's committee key
        Packet memory currentPacket = packets[stream.streamId][stream.peginPointer];
        bytes32 committeeKey = currentPacket.committeePubKey;

        return bitcoinManager.getTemporaryPegInAddress(
            _rootstockDepositAddress, _value, _btcReimbursementPubKey, committeeKey
        );
    }

    function registerPegInRequest(BtcTxSPVProof calldata _pegInRequestTxSPVProof) external {
        // Calculate txHash from BtcTransaction
        bytes32 txHash = bitcoinManager.getBtcTxHash(_pegInRequestTxSPVProof.btcTx);
        if (pegInRequests[txHash].pegStatus != PegStatus.NOT_REGISTERED) {
            revert AlreadyRegisteredPegInRequest(txHash);
        }
        // Validate transaction has at least 2 outputs
        if (_pegInRequestTxSPVProof.btcTx.outputs.length < 2) {
            revert IncorrectOutputsNumber(uint64(_pegInRequestTxSPVProof.btcTx.outputs.length), 2);
        }
        // Second transaction should be OP_RETURN with data
        (uint64 packetNumber, address rskDestinationAddress, bytes32 btcReimbursementPubKey) =
            bitcoinManager.getPegInOpReturnData(_pegInRequestTxSPVProof.btcTx.outputs[VOUT_INDEX_SPEED_UP]);
        // First transaction is the PegIn P2TR _pegInRequestTxSPVProof.btcTx.outputs[0]
        // Get corresponding stream for the amount if non found reverts
        Stream memory stream = getStream(_pegInRequestTxSPVProof.btcTx.outputs[VOUT_INDEX_TAPTREE].amount);

        // Validates that the Taproot Script has a Key Path for the committeePubKey
        // and has a timelock for btcReimbursementPubKey
        bitcoinManager.validatRequestPegInP2TROutput(
            rskDestinationAddress,
            stream.denomination,
            btcReimbursementPubKey,
            // getPacket reverts if packet does not exist
            getPacket(stream.streamId, packetNumber).committeePubKey,
            _pegInRequestTxSPVProof.btcTx.outputs[VOUT_INDEX_TAPTREE]
        );

        // Verify the txHash part of the Merkle Root of Tx of a Block
        // and that block is inside Bitcoin Mainchain
        // annd has enough confirmations
        verifyTxConfirmations(
            stream.pegInConfirmations,
            txHash,
            _pegInRequestTxSPVProof.blockHash,
            _pegInRequestTxSPVProof.merkleBranchPath,
            _pegInRequestTxSPVProof.merkleBranchHashes
        );
        // Store pegInRequest to avoid processing it again
        pegInRequests[txHash] = StreamPosition({
            streamId: stream.streamId,
            packetNumber: packetNumber,
            slotId: 0,
            pegStatus: PegStatus.REGISTERED
        });
        // Store tempprary information to be used in acceptPegInRequest
        pegInsTempInfo[txHash] = RequestPegInTempInfo({
            // TODO check if this is gona be used, or just use the stream.denomination
            outputAmount: _pegInRequestTxSPVProof.btcTx.outputs[VOUT_INDEX_TAPTREE].amount,
            rskDestinationAddress: rskDestinationAddress,
            btcReimbursementPubKey: btcReimbursementPubKey,
            // TODO utxoScriptPubKey is not used yet but it will be used when checking the signatures in verifyAcceptPegInTxSignatures
            utxoScriptPubKey: _pegInRequestTxSPVProof.btcTx.outputs[VOUT_INDEX_TAPTREE].scriptPubKey
        });

        // TODO Check if info emitted is enough or too much
        emit RegisteredPegInRequest(
            _pegInRequestTxSPVProof.blockHash,
            txHash,
            VOUT_INDEX_TAPTREE, // vout is the first output, is the P2TR
            stream.denomination,
            packetNumber,
            rskDestinationAddress,
            btcReimbursementPubKey,
            _pegInRequestTxSPVProof.btcTx.outputs[VOUT_INDEX_TAPTREE].scriptPubKey
        );
    }

    function validateAcceptPegInTx(BtcTransaction memory _btcTx)
        internal
        view
        returns (
            bytes32 requestPegInTxHash,
            RequestPegInTempInfo memory requestTempInfo,
            StreamPosition storage streamPosition
        )
    {
        // Only input is the peg in request utxo
        if (_btcTx.inputs.length != 1) {
            revert IncorrectInputsNumber(_btcTx.inputs.length, 1);
        }
        // Only 2 outputs, peg out and speed up (child pays for parent)
        if (_btcTx.outputs.length != 2) {
            revert IncorrectOutputsNumber(_btcTx.outputs.length, 2);
        }

        // TODO validate amount of btc is correct

        // The first input consumes the the peg in request utxo
        requestPegInTxHash = _btcTx.inputs[VOUT_INDEX_TAPTREE].txId;
        // Validate that in the first input VOUT is 0
        if (_btcTx.inputs[VOUT_INDEX_TAPTREE].vout != VOUT_INDEX_TAPTREE) {
            revert InvalidVout(_btcTx.inputs[VOUT_INDEX_TAPTREE].vout, VOUT_INDEX_TAPTREE);
        }

        // Validate the peg in request tx exists and the status
        streamPosition = pegInRequests[requestPegInTxHash];
        if (streamPosition.pegStatus == PegStatus.NOT_REGISTERED) {
            revert UnregisteredPegInRequest(requestPegInTxHash);
        }
        if (streamPosition.pegStatus != PegStatus.REGISTERED) {
            revert AlreadyRegisteredAcceptPegIn(requestPegInTxHash);
        }

        // TODO validate the input taproot script is correct
        // It should be the taproot key spend path and not the timelock leaf
        // this goes in the witness of the transaction
        // if not validated a user could spend the timelock
        // and use the same outputs as the expected ones and the transaction would be valid
        // not sure if this can be used as an attack tough

        requestTempInfo = pegInsTempInfo[requestPegInTxHash];
        bytes32 committeePubKey = getPacket(streamPosition.streamId, streamPosition.packetNumber).committeePubKey;
        // validate the ouputs are the expected
        // taptree for pegout
        bitcoinManager.validateAcceptPegInP2TROutput(
            committeePubKey, requestTempInfo.outputAmount, _btcTx.outputs[VOUT_INDEX_TAPTREE]
        );
        // spped up (child pays for parent)
        bitcoinManager.validateSpeedUpOutput(
            requestTempInfo.btcReimbursementPubKey, _btcTx.outputs[VOUT_INDEX_SPEED_UP]
        );
    }

    function acceptPegInRequest(BtcTxSPVProof calldata _pegInAcceptedTxSPVProof) external {
        // validate the inputs match the request pegin and outputs are the expected taptree and speed up
        (bytes32 requestPegInTxHash, RequestPegInTempInfo memory requestTempInfo, StreamPosition storage streamPosition)
        = validateAcceptPegInTx(_pegInAcceptedTxSPVProof.btcTx);

        // Calculate txHash from BtcTransaction
        bytes32 txHash = bitcoinManager.getBtcTxHash(_pegInAcceptedTxSPVProof.btcTx);

        // Verify the txHash part of the Merkle Root of Tx of a Block
        // and that block is inside Bitcoin Mainchain
        // annd has enough confirmations
        verifyTxConfirmations(
            streams[streamPosition.streamId].pegInConfirmations,
            txHash,
            _pegInAcceptedTxSPVProof.blockHash,
            _pegInAcceptedTxSPVProof.merkleBranchPath,
            _pegInAcceptedTxSPVProof.merkleBranchHashes
        );

        // get the peg in request tx hash
        // Store Tx in pegInSlot as Filled
        streamPosition.slotId = fillPegInTx(
            streamPosition.streamId,
            streamPosition.packetNumber,
            _pegInAcceptedTxSPVProof.btcTx.outputs[VOUT_INDEX_TAPTREE].amount,
            txHash
        );
        // Update the peg in request status to ACCEPTED
        streamPosition.pegStatus = PegStatus.ACCEPTED;

        // === TODO STORE ACCEPT VALUE INTO THE SLOT SO ITS USED FOR THE PEG OUT ===

        // TODO should we use the tempInfo.outputAmount or the acceptPegInAmount
        uint256 rbtcAmount = BtcHelper.satoshiToWei(_pegInAcceptedTxSPVProof.btcTx.outputs[VOUT_INDEX_TAPTREE].amount);

        emit AcceptedPegInRequest(
            _pegInAcceptedTxSPVProof.blockHash,
            txHash,
            requestPegInTxHash,
            VOUT_INDEX_TAPTREE,
            streamPosition,
            requestTempInfo.btcReimbursementPubKey,
            requestTempInfo.rskDestinationAddress,
            rbtcAmount,
            _pegInAcceptedTxSPVProof.btcTx.outputs[VOUT_INDEX_TAPTREE].scriptPubKey
        );

        // TODO mint the peg in tokens
        //requestRbtc(rskDestinationAddress, rbtcAmount);

        // Get gas refund for deleteing the peg in request tx
        // since we have the accept peg in tx it is not needed anymore
        delete pegInsTempInfo[requestPegInTxHash];
    }

    function validatePegOutRequest(bytes calldata _usrPubKey, uint256 amountInWei) internal pure {
        if (BtcHelper.weiToSatoshi(amountInWei) > type(uint64).max) {
            revert PegoutRequestAmountExceedsUint64Limit(BtcHelper.weiToSatoshi(amountInWei));
        }

        // Validate the _usrPubKey is 33 bytes
        if (_usrPubKey.length != 33) {
            revert InvalidPubKeyLength(_usrPubKey.length);
        }

        // TODO: validate who can request a peg-out
    }

    function requestPegOut(bytes calldata _usrPubKey, bool _batchFlag) external payable {
        validatePegOutRequest(_usrPubKey, msg.value);

        uint64 receivedAmount = uint64(BtcHelper.weiToSatoshi(msg.value));
        // TODO: acount for batchFlag

        // Get first filled Slot
        Stream memory stream = getStream(receivedAmount);
        (Slot memory slot, uint64 packetNumber) = getFirstFilledSlot(stream.streamId);

        // Prepare prevout data
        PrevoutData memory prevoutData = PrevoutData({
            txid: slot.acceptPegInTx,
            vout: 0,
            value: slot.acceptPegInAmount,
            scriptPubKey: slot.scriptPubKey
        });

        // Calculate fee and dust from amount
        // TODO: atm is returning hardcoded values, should be calculated
        (uint64 fee, uint64 dust) = BtcHelper.calculateFeeAndDust(slot.acceptPegInAmount);

        // Compute the Bitcoin peg-out transaction hash
        (bytes32 pegOutTxHash, bytes memory digest) =
            computePegOutTxHash(_usrPubKey, prevoutData, slot.acceptPegInAmount - dust - fee, dust);

        // Store the peg-out transaction hash on-chain
        pegOutTxHashes[keccak256(abi.encodePacked(_usrPubKey, stream.denomination))] = pegOutTxHash;

        // Lock the used slot
        lockSlot(stream.streamId, packetNumber, slot.slotId);

        // TODO: return RBTC to the RSK Legacy Bridge following https://github.com/rsksmart/RSKIPs/pull/502

        // Emit an event
        emit PegOutRequested(
            _usrPubKey, stream.denomination, pegOutTxHash, digest, stream.streamId, packetNumber, slot.slotId
        );
    }

    function computePegOutTxHash(bytes memory usrPubKey, PrevoutData memory prevoutData, uint64 amount, uint64 dust)
        public
        pure
        returns (bytes32, bytes memory)
    {
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
        bytes32 sha_sequences = sha256(abi.encodePacked(BtcHelper.reverseUint32(uint32(bytes4(hex"FFFFFFFD")))));

        // Prepare the outputs, user and speed up
        bytes memory scriptPubKey = BtcScriptParser.getP2WPKHScript(usrPubKey);
        bytes memory outputs = abi.encodePacked(
            BtcHelper.reverseUint64(amount), BtcHelper.toCompactSize(scriptPubKey.length), scriptPubKey
        );

        // User is in charge of the speedup to avoid reciclyng attacks
        bytes memory speedUpScriptPubKey = scriptPubKey;
        outputs = abi.encodePacked(
            outputs,
            BtcHelper.reverseUint64(dust),
            BtcHelper.toCompactSize(speedUpScriptPubKey.length),
            speedUpScriptPubKey
        );

        // sha_outputs (32): the SHA256 of the serialization of all outputs in CTxOut format.
        bytes32 sha_outputs = sha256(outputs);

        // Concatenate all the data
        bytes memory encodedData = abi.encodePacked(
            uint8(0), // epoch
            uint8(0x01), // hash_type
            bytes4(hex"02000000"), // nVersion
            uint32(0), // nLockTime
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

    function getPegOutTxHash(bytes32 key) external view returns (bytes32) {
        return pegOutTxHashes[key];
    }
}
