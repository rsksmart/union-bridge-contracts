// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {BaseProxy} from "./BaseProxy.sol";
import {Committee, CommitteeMember, ICommitteeRegistry} from "./interfaces/ICommitteeRegistry.sol";
import {PrevoutData, BtcTransaction, BtcTxOut, IBitcoinManager} from "./interfaces/IBitcoinManager.sol";
import {
    BtcTxSPVProof,
    StreamPosition,
    RequestPegInTempInfo,
    PegStatus,
    SignatureData,
    Signatures,
    IPegManager
} from "./interfaces/IPegManager.sol";
import {Slot, Stream, Packet, SlotState, IStreamManager} from "./interfaces/IStreamManager.sol";
import {ProofValidator} from "./ProofValidator.sol";
import {BtcHelper} from "./libraries/BtcHelper.sol";
import {Constants} from "./libraries/Constants.sol";

/// @title PegManager
/// @notice Manages peg-in and peg-out operations between Bitcoin and Rootstock

contract PegManager is IPegManager, ProofValidator, BaseProxy {
    ICommitteeRegistry public committeeRegistry;
    IBitcoinManager public bitcoinManager;
    IStreamManager public streamManager;

    // Request PegIn Tx Hash => Stream Position (streamId, packetNumber, slotId, pegStatus)
    mapping(bytes32 btcRequestPegInTxHash => StreamPosition streamPosition) internal pegInRequests;
    // Request PegIn Tx Hash => PegIn Temp Info (value, rskDestinationAddress, btcReimbursementPubKey)
    mapping(bytes32 btcRequestPegInTxHash => RequestPegInTempInfo tempInfo) internal pegInsTempInfo;
    mapping(bytes32 btcRequestPegInTxHash => bytes32 acceptPegInSignatureHash) internal accpetPegInSighashes;
    // key = keccak256(abi.encodePacked(streamId, packetNumber, slotId))
    mapping(bytes32 key => bytes32 pegOutSignatureHash) internal pegOutSighashes;
    // Signatures waiting for the committee to sign
    mapping(bytes32 signatureHash => Signatures signatures) internal committeeSignatures;

    function initialize(
        address _initialOwner,
        address payable _bridgeAddress,
        ICommitteeRegistry _committeeRegistry,
        IBitcoinManager _bitcoinManager
    ) public virtual initializer {
        committeeRegistry = _committeeRegistry;
        bitcoinManager = _bitcoinManager;
        __ProofValidator_init(_bridgeAddress);
        __BaseProxy_init(_initialOwner);
    }

    function setStreamManager(IStreamManager _streamManager) external onlyOwner {
        streamManager = _streamManager;
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
        Stream memory stream = streamManager.getStream(_value);

        // Get the current packet's committee key
        Packet memory currentPacket = streamManager.getPacket(stream.streamId, stream.peginPointer);
        bytes32 committeeKey = currentPacket.committeePubKey;

        return bitcoinManager.getTemporaryPegInAddress(
            _rootstockDepositAddress, _value, _btcReimbursementPubKey, committeeKey
        );
    }

    function registerPegInRequest(BtcTxSPVProof calldata _pegInRequestTxSPVProof) external {
        if (_pegInRequestTxSPVProof.btcTx.version != Constants.BTC_TX_VERSION) {
            revert InvalidBtcTxVersion(_pegInRequestTxSPVProof.btcTx.version, Constants.BTC_TX_VERSION);
        }
        if (_pegInRequestTxSPVProof.btcTx.locktime != Constants.LOCKTIME) {
            revert InvalidLocktime(_pegInRequestTxSPVProof.btcTx.locktime, Constants.LOCKTIME);
        }
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
            bitcoinManager.getPegInOpReturnData(_pegInRequestTxSPVProof.btcTx.outputs[Constants.VOUT_INDEX_SPEED_UP]);
        // First transaction is the PegIn P2TR _pegInRequestTxSPVProof.btcTx.outputs[0]
        // Get corresponding stream for the amount if non found reverts
        Stream memory stream =
            streamManager.getStream(_pegInRequestTxSPVProof.btcTx.outputs[Constants.VOUT_INDEX_TAPTREE].amount);

        // getCommitteePubKey reverts if packet does not exist
        bytes32 committeePubKey = streamManager.getCommitteePubKey(stream.streamId, packetNumber);

        // Validates that the Taproot Script has a Key Path for the committeePubKey
        // and has a timelock for btcReimbursementPubKey
        bitcoinManager.validatRequestPegInP2TROutput(
            rskDestinationAddress,
            stream.denomination,
            btcReimbursementPubKey,
            committeePubKey,
            _pegInRequestTxSPVProof.btcTx.outputs[Constants.VOUT_INDEX_TAPTREE]
        );

        // Verify the txHash part of the Merkle Root of Tx of a Block
        // and that block is inside Bitcoin Mainchain
        // and has enough confirmations
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
            outputAmount: _pegInRequestTxSPVProof.btcTx.outputs[Constants.VOUT_INDEX_TAPTREE].amount,
            rskDestinationAddress: rskDestinationAddress,
            btcReimbursementPubKey: btcReimbursementPubKey,
            // TODO utxoScriptPubKey is not used yet but it will be used when checking the signatures in verifyAcceptPegInTxSignatures
            utxoScriptPubKey: _pegInRequestTxSPVProof.btcTx.outputs[Constants.VOUT_INDEX_TAPTREE].scriptPubKey
        });

        emit RegisteredPegInRequest(
            _pegInRequestTxSPVProof.blockHash,
            txHash,
            Constants.VOUT_INDEX_TAPTREE, // vout is the first output, is the P2TR
            stream.denomination,
            packetNumber,
            rskDestinationAddress,
            btcReimbursementPubKey,
            _pegInRequestTxSPVProof.btcTx.outputs[Constants.VOUT_INDEX_TAPTREE].scriptPubKey
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
        if (_btcTx.version != Constants.BTC_TX_VERSION) {
            revert InvalidBtcTxVersion(_btcTx.version, Constants.BTC_TX_VERSION);
        }
        if (_btcTx.locktime != Constants.LOCKTIME) {
            revert InvalidLocktime(_btcTx.locktime, Constants.LOCKTIME);
        }
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
        requestPegInTxHash = _btcTx.inputs[Constants.VOUT_INDEX_TAPTREE].txId;
        // Validate that in the first input VOUT is 0
        if (_btcTx.inputs[Constants.VOUT_INDEX_TAPTREE].vout != Constants.VOUT_INDEX_TAPTREE) {
            revert InvalidVout(_btcTx.inputs[Constants.VOUT_INDEX_TAPTREE].vout, Constants.VOUT_INDEX_TAPTREE);
        }
        // Validate the sequence is 0xFFFFFFFD
        if (_btcTx.inputs[Constants.VOUT_INDEX_TAPTREE].sequence != Constants.SEQUENCE) {
            revert InvalidSequence(_btcTx.inputs[Constants.VOUT_INDEX_TAPTREE].sequence, Constants.SEQUENCE);
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
        bytes32 committeePubKey = streamManager.getCommitteePubKey(streamPosition.streamId, streamPosition.packetNumber);
        // validate the ouputs are the expected
        // taptree for pegout
        bitcoinManager.validateAcceptPegInP2TROutput(
            committeePubKey, requestTempInfo.outputAmount, _btcTx.outputs[Constants.VOUT_INDEX_TAPTREE]
        );
        // spped up (child pays for parent)
        bitcoinManager.validateSpeedUpOutput(
            requestTempInfo.btcReimbursementPubKey, _btcTx.outputs[Constants.VOUT_INDEX_SPEED_UP]
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
            streamManager.getStreamById(streamPosition.streamId).pegInConfirmations,
            txHash,
            _pegInAcceptedTxSPVProof.blockHash,
            _pegInAcceptedTxSPVProof.merkleBranchPath,
            _pegInAcceptedTxSPVProof.merkleBranchHashes
        );

        // get the peg in request tx hash
        // Store Tx in pegInSlot as Filled
        streamPosition.slotId = streamManager.fillAcceptPegInTx(
            streamPosition.streamId,
            streamPosition.packetNumber,
            _pegInAcceptedTxSPVProof.btcTx.outputs[Constants.VOUT_INDEX_TAPTREE].amount,
            txHash,
            _pegInAcceptedTxSPVProof.btcTx.outputs[Constants.VOUT_INDEX_TAPTREE].scriptPubKey
        );
        // Update the peg in request status to ACCEPTED
        streamPosition.pegStatus = PegStatus.ACCEPTED;

        // Check if we need a new packet
        if (streamPosition.slotId == Constants.SLOT_USAGE_THRESHOLD - 1) {
            bytes32 committeePubKey = committeeRegistry.selectCommittee(streamPosition.streamId);
            streamManager.createNewPacket(streamPosition.streamId, committeePubKey);
        }

        // Check if we need to move the packet pointer
        if (streamPosition.slotId == Constants.SLOTS_PER_PACKET - 1) {
            streamManager.incrementPacketPeginPointer(streamPosition.streamId);
        }

        // === TODO STORE ACCEPT VALUE INTO THE SLOT SO ITS USED FOR THE PEG OUT ===

        // TODO should we use the tempInfo.outputAmount or the acceptPegInAmount
        uint256 rbtcAmount =
            BtcHelper.satoshiToWei(_pegInAcceptedTxSPVProof.btcTx.outputs[Constants.VOUT_INDEX_TAPTREE].amount);

        emit AcceptedPegInRequest(
            _pegInAcceptedTxSPVProof.blockHash,
            txHash,
            requestPegInTxHash,
            Constants.VOUT_INDEX_TAPTREE,
            streamPosition,
            requestTempInfo.btcReimbursementPubKey,
            requestTempInfo.rskDestinationAddress,
            rbtcAmount,
            _pegInAcceptedTxSPVProof.btcTx.outputs[Constants.VOUT_INDEX_TAPTREE].scriptPubKey
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

    function requestPegOut(bytes calldata _usrPubKey) external payable {
        validatePegOutRequest(_usrPubKey, msg.value);

        uint64 receivedAmount = uint64(BtcHelper.weiToSatoshi(msg.value));

        // Get first filled Slot
        Stream memory stream = streamManager.getStream(receivedAmount);
        (Slot memory slot, uint64 packetNumber) = streamManager.getFirstFilledSlot(stream.streamId);

        // Prepare prevout data
        PrevoutData memory prevoutData = PrevoutData({value: slot.acceptPegInAmount, scriptPubKey: slot.scriptPubKey});

        // Compute the Bitcoin peg-out transaction hash
        (bytes32 pegOutSignatureHash, bytes memory commonSignatureMessage) =
            bitcoinManager.getPegOutSignatureHash(_usrPubKey, slot.acceptPegInTx, prevoutData);

        // Store the peg-out transaction hash on-chain and initialize the signatures
        storePegOutAndInitSignatures(pegOutSignatureHash, stream.streamId, packetNumber, slot.slotId);

        // Lock the used slot
        streamManager.lockSlot(stream.streamId, packetNumber, slot.slotId);

        // TODO: return RBTC to the RSK Legacy Bridge following https://github.com/rsksmart/RSKIPs/pull/502

        emit PegOutRequested(
            _usrPubKey,
            stream.denomination,
            pegOutSignatureHash,
            commonSignatureMessage,
            stream.streamId,
            packetNumber,
            slot.slotId
        );
    }

    function getPegOutSignatureHash(uint64 streamId, uint64 packetNumber, uint64 slotId)
        external
        view
        returns (bytes32)
    {
        bytes32 key = keccak256(abi.encodePacked(streamId, packetNumber, slotId));
        return pegOutSighashes[key];
    }

    function storePegOutAndInitSignatures(
        bytes32 pegOutSignatureHash,
        uint64 streamId,
        uint64 packetNumber,
        uint64 slotId
    ) internal {
        // Store the peg-out transaction hash on-chain and initialize the signatures
        bytes32 key = keccak256(abi.encodePacked(streamId, packetNumber, slotId));
        pegOutSighashes[key] = pegOutSignatureHash;

        // Get the committee key
        bytes32 committeeKey = streamManager.getCommitteePubKey(streamId, packetNumber);

        // Get the members
        CommitteeMember[] memory members = committeeRegistry.getCommitteeMember(committeeKey);

        // Initialize the signatures for each member
        Signatures storage signatures = committeeSignatures[pegOutSignatureHash];
        for (uint256 i = 0; i < members.length; i++) {
            signatures.signaturesData.push(
                SignatureData({
                    memberPublicKey: committeeRegistry.getMemberPubKeyByIndex(members[i].index),
                    signature: "",
                    nonce: ""
                })
            );
        }
        // Initialize missing signatures counter
        signatures.missingSignatures = uint8(members.length);
    }

    function addMemberSignature(bytes32 _signatureHash, bytes32 _signature, bytes memory _nonce)
        external
        returns (bool)
    {
        // Check if the peg-out transaction hash exists
        checkSignatureHashValidity(_signatureHash);

        // Check if caller is a valid member
        bytes32 memberPubKey = committeeRegistry.getMemberPubKeyByAddress(_msgSender());
        if (memberPubKey == bytes32(0)) {
            revert MemberNotFound(_msgSender());
        }

        // Check that nonce is 66 bytes
        if (_nonce.length != Constants.SIGNATURE_NONCE_LENGTH) {
            revert InvalidNonceLength(_nonce.length, Constants.SIGNATURE_NONCE_LENGTH);
        }

        // Store the signature and nonce for the member
        bool found = false;
        Signatures storage signatures = committeeSignatures[_signatureHash];
        SignatureData[] storage signaturesData = signatures.signaturesData;
        for (uint256 i = 0; i < signaturesData.length; i++) {
            if (signaturesData[i].memberPublicKey == memberPubKey) {
                if (signaturesData[i].signature != "") {
                    revert MemberHasAlreadySigned(memberPubKey, _msgSender(), _signatureHash);
                }
                signaturesData[i].signature = _signature;
                signaturesData[i].nonce = _nonce;
                found = true;
                signatures.missingSignatures -= 1;
                emit SignatureAdded(_signatureHash, memberPubKey, _signature, _nonce);
                break;
            }
        }
        if (!found) {
            revert MemberNotFoundInCommittee(memberPubKey, _signatureHash);
        }

        // Check if all signatures are present
        if (committeeSignatures[_signatureHash].missingSignatures != 0) {
            return false;
        }
        emit AllSignaturesReady(_signatureHash);
        return true;
    }

    function checkAllSignaturesReady(bytes32 _signatureHash) external view returns (bool) {
        checkSignatureHashValidity(_signatureHash);
        if (committeeSignatures[_signatureHash].missingSignatures != 0) {
            return false;
        }
        return true;
    }

    function checkSignatureHashValidity(bytes32 _signatureHash) internal view {
        // Check if the signature hash exists
        if (committeeSignatures[_signatureHash].signaturesData.length == 0) {
            revert SignatureHashNotFound(_signatureHash);
        }
    }

    function getPacketPeginPointer(uint64 _streamId) internal view returns (uint64) {
        return streamManager.getPacketPeginPointer(_streamId);
    }
}
