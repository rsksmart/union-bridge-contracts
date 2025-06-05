// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {BaseProxy} from "./BaseProxy.sol";
import {ICommitteeRegistry, CommitteeMember} from "./interfaces/ICommitteeRegistry.sol";
import {ISignatureManager, Signatures, SignatureData} from "./interfaces/ISignatureManager.sol";
import {PrevoutData, BtcTransaction, BtcTxOut, IBitcoinManager} from "./interfaces/IBitcoinManager.sol";
import {
    BtcTxSPVProof,
    RequestPegInTempInfo,
    PegOutTempInfo,
    StreamPosition,
    PegStatus,
    IPegManager
} from "./interfaces/IPegManager.sol";
import {Slot, Stream, Packet, SlotState, IStreamManager} from "./interfaces/IStreamManager.sol";
import {ProofValidator} from "./ProofValidator.sol";
import {BtcHelper} from "./libraries/BtcHelper.sol";
import {BytesHelper} from "./libraries/BytesHelper.sol";
import {Constants} from "./libraries/Constants.sol";
import {BtcScriptParser} from "./libraries/BtcScriptParser.sol";

/// @title PegManager
/// @notice Manages peg-in and peg-out operations between Bitcoin and Rootstock

contract PegManager is IPegManager, BaseProxy, ProofValidator {
    IBitcoinManager public bitcoinManager;
    IStreamManager public streamManager;
    ICommitteeRegistry public committeeRegistry;
    ISignatureManager public signatureManager;

    mapping(bytes32 requestPegInTxHash => bytes32 acceptPeginTxhash) internal pegInRequests;
    mapping(bytes32 acceptPeginTxhash => StreamPosition streamPosition) internal streamPosition;
    mapping(bytes32 requestPegInTxHash => RequestPegInTempInfo tempInfo) internal pegInTempInfo;
    mapping(bytes32 acceptPegInTxHash => PegOutTempInfo tempInfo) internal pegOutTempInfo;

    // key = keccak256(abi.encodePacked(streamId, packetNumber, slotId))
    mapping(bytes32 key => bytes32 pegOutSignatureHash) internal pegOutSighashes;

    function initialize(
        address _initialOwner,
        address payable _bridgeAddress,
        ICommitteeRegistry _committeeRegistry,
        IBitcoinManager _bitcoinManager
    ) public virtual initializer {
        // Validate that the bitcoin manager is not zero address
        if (address(_bitcoinManager) == address(0)) {
            revert BitcoinManagerAddressZero();
        }
        bitcoinManager = _bitcoinManager;

        if (address(_committeeRegistry) == address(0)) {
            revert CommitteeRegistryAddressZero();
        }
        committeeRegistry = _committeeRegistry;

        __BaseProxy_init(_initialOwner);
        __ProofValidator_init(_bridgeAddress);
    }

    function setStreamManager(IStreamManager _streamManager) external onlyOwner {
        if (address(_streamManager) == address(0)) {
            revert StreamManagerAddressZero();
        }
        streamManager = _streamManager;
    }

    function setSignatureManager(ISignatureManager _signatureManager) external onlyOwner {
        if (address(_signatureManager) == address(0)) {
            revert SignatureManagerAddressZero();
        }
        signatureManager = _signatureManager;
    }

    function getPegInRequest(bytes32 _btcTxHash) external view returns (bytes32) {
        return pegInRequests[_btcTxHash];
    }

    function getRequestPegInTempInfo(bytes32 _btcTxHash) external view returns (RequestPegInTempInfo memory) {
        return pegInTempInfo[_btcTxHash];
    }

    function getPegTempOutInfo(bytes32 _acceptPegInTxHash) external view returns (PegOutTempInfo memory) {
        return pegOutTempInfo[_acceptPegInTxHash];
    }

    function getTemporaryPegInAddress(address _rootstockDepositAddress, uint64 _value, bytes32 _btcReimbursementPubKey)
        external
        view
        returns (string memory bitcoinDepositAddress)
    {
        // Get the stream for this value
        Stream memory stream = streamManager.getStream(_value);

        // Get the current packet's committee key
        Packet memory currentPacket = streamManager.getPacket(stream.streamId, stream.peginPacketPointer);
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
        if (getStreamPosition(txHash).pegStatus != PegStatus.NOT_REGISTERED) {
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
            stream.peginConfirmations,
            txHash,
            _pegInRequestTxSPVProof.blockHash,
            _pegInRequestTxSPVProof.merkleBranchPath,
            _pegInRequestTxSPVProof.merkleBranchHashes
        );

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

        _initAcceptPegin(
            committeePubKey,
            btcReimbursementPubKey,
            txHash,
            rskDestinationAddress,
            PrevoutData({
                value: _pegInRequestTxSPVProof.btcTx.outputs[Constants.VOUT_INDEX_TAPTREE].amount,
                scriptPubKey: _pegInRequestTxSPVProof.btcTx.outputs[Constants.VOUT_INDEX_TAPTREE].scriptPubKey
            }),
            stream.streamId,
            packetNumber
        );
    }

    function _initAcceptPegin(
        bytes32 _committeePubKey,
        bytes32 _userXOnlyPubKey,
        bytes32 _registerPegInTx,
        address _rskDestinationAddress,
        PrevoutData memory _prevoutData,
        uint64 _streamId,
        uint64 _packetNumber
    ) internal {
        // Compute the Bitcoin accept peg-in transaction signature hash
        (bytes32 acceptPeginTxHash, bytes32 acceptPeginSignatureHash, bytes memory acceptPeginSignatureMessage) =
        bitcoinManager.getAcceptPegInSignatureHash(_committeePubKey, _userXOnlyPubKey, _registerPegInTx, _prevoutData);

        // Store pegInRequest txHash to avoid processing it again
        pegInRequests[_registerPegInTx] = acceptPeginTxHash;
        streamPosition[acceptPeginTxHash] = StreamPosition({
            streamId: _streamId,
            packetNumber: _packetNumber,
            slotId: 0,
            pegStatus: PegStatus.REGISTERED
        });

        // Store pegIn info needed for acceptPegIn
        pegInTempInfo[_registerPegInTx] = RequestPegInTempInfo({
            rskDestinationAddress: _rskDestinationAddress,
            btcReimbursementPubKey: _userXOnlyPubKey,
            acceptPeginSignatureHash: acceptPeginSignatureHash,
            acceptPeginTxHash: acceptPeginTxHash
        });

        emit InitAcceptPegin(_committeePubKey, _registerPegInTx, acceptPeginSignatureHash, acceptPeginSignatureMessage);

        // Initialize the signatures needed for a given aggregated key
        uint256 committeeId = streamManager.getCommitteeId(_streamId, _packetNumber);
        signatureManager.initSignatures(acceptPeginSignatureHash, committeeId);
    }

    function acceptPegInRequest(BtcTxSPVProof calldata _pegInAcceptedTxSPVProof) external {
        // The first input consumes the the peg in request utxo
        bytes32 requestPegInTxHash = _pegInAcceptedTxSPVProof.btcTx.inputs[Constants.VOUT_INDEX_TAPTREE].txId;

        // Get the peg in request temp info
        RequestPegInTempInfo storage requestTempInfo = pegInTempInfo[requestPegInTxHash];

        // Validate the peg in request tx exists and the status
        StreamPosition memory streamInfo = getStreamPosition(requestPegInTxHash);
        if (streamInfo.pegStatus == PegStatus.NOT_REGISTERED) {
            revert UnregisteredPegInRequest(requestPegInTxHash);
        }
        if (streamInfo.pegStatus != PegStatus.REGISTERED) {
            revert AlreadyRegisteredAcceptPegIn(requestPegInTxHash);
        }

        // Calculate txHash from BtcTransaction
        bytes32 txHash = bitcoinManager.getBtcTxHash(_pegInAcceptedTxSPVProof.btcTx);

        // Validate the txhash is the same calculated at request peg in tx
        if (requestTempInfo.acceptPeginTxHash != txHash) {
            revert InvalidAcceptPegInTxHash(requestTempInfo.acceptPeginTxHash, txHash);
        }

        // Verify the txHash part of the Merkle Root of Tx of a Block
        // and that block is inside Bitcoin Mainchain
        // annd has enough confirmations
        verifyTxConfirmations(
            streamManager.getStreamById(streamInfo.streamId).peginConfirmations,
            txHash,
            _pegInAcceptedTxSPVProof.blockHash,
            _pegInAcceptedTxSPVProof.merkleBranchPath,
            _pegInAcceptedTxSPVProof.merkleBranchHashes
        );

        _storePegInAndInitSignatures(
            requestPegInTxHash,
            streamInfo,
            requestTempInfo,
            _pegInAcceptedTxSPVProof.blockHash,
            txHash,
            _pegInAcceptedTxSPVProof.btcTx.outputs[Constants.VOUT_INDEX_TAPTREE]
        );
    }

    function _storePegInAndInitSignatures(
        bytes32 _requestPegInTxHash,
        StreamPosition memory streamInfo,
        RequestPegInTempInfo storage requestTempInfo,
        bytes32 _blockHash,
        bytes32 _txHash,
        BtcTxOut memory _acceptPeginTxOutput
    ) internal {
        // Update the peg in request status to ACCEPTED to avoid processing it again
        streamPosition[_txHash].pegStatus = PegStatus.ACCEPTED;

        // Store Tx in pegInSlot as Filled
        streamPosition[_txHash].slotId = streamManager.fillAcceptPegInTx(
            streamInfo.streamId,
            streamInfo.packetNumber,
            _acceptPeginTxOutput.amount,
            _txHash,
            _acceptPeginTxOutput.scriptPubKey
        );

        // Check if we need a new packet/committee
        // NOTE: Compare directly with Constants.SLOT_USAGE_THRESHOLD. It is not mathematically correct but it's functionally the same
        if (streamPosition[_txHash].slotId == Constants.SLOT_USAGE_THRESHOLD - 1) {
            committeeRegistry.createCommittee(streamPosition[_txHash].streamId);
        }

        if (streamPosition[_txHash].slotId >= Constants.SLOT_USAGE_THRESHOLD) {
            if (committeeRegistry.isPendingCommitteeExpired(streamPosition[_txHash].streamId)) {
                committeeRegistry.createCommittee(streamPosition[_txHash].streamId);
            }
        }

        uint256 rbtcAmount = BtcHelper.satoshiToWei(_acceptPeginTxOutput.amount);

        emit AcceptedPegInRequest(
            _blockHash,
            _txHash,
            _requestPegInTxHash,
            Constants.VOUT_INDEX_TAPTREE,
            streamPosition[_txHash],
            requestTempInfo.btcReimbursementPubKey,
            requestTempInfo.rskDestinationAddress,
            rbtcAmount,
            _acceptPeginTxOutput.scriptPubKey
        );

        // TODO mint the peg in tokens
        //requestRbtc(rskDestinationAddress, rbtcAmount);
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
        (Slot memory slot, uint64 packetNumber) = streamManager.lockSlot(stream.streamId);

        // Prepare prevout data
        PrevoutData memory prevoutData = PrevoutData({value: slot.acceptPegInAmount, scriptPubKey: slot.scriptPubKey});

        // Compute the Bitcoin peg-out signature hash
        (bytes32 pegOutSignatureHash, bytes memory commonSignatureMessage) =
            bitcoinManager.getPegOutSignatureHash(_usrPubKey, slot.acceptPegInTx, prevoutData);

        // Store the pegout transaction info for efficient lookup during registration
        pegOutTempInfo[slot.acceptPegInTx] = PegOutTempInfo({userPubKey: _usrPubKey});

        // Store the peg-out transaction hash on-chain and initialize the signatures
        storePegOutAndInitSignatures(pegOutSignatureHash, stream.streamId, packetNumber, slot.slotId);

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

    /// @notice Register a peg-out transaction from Bitcoin
    /// @param _pegOutTxSPVProof The BTC SPV proof of the peg-out transaction
    function registerPegout(BtcTxSPVProof calldata _pegOutTxSPVProof) external {
        // Get the accept peg-in tx hash from the first input (this is what gets spent)
        bytes32 acceptPegInTxHash = _pegOutTxSPVProof.btcTx.inputs[0].txId;
        uint32 vout = _pegOutTxSPVProof.btcTx.inputs[0].vout;

        // get the stream data for this pegout
        StreamPosition memory streamInfo = streamPosition[acceptPegInTxHash];

        // Validate that the vout is correct
        if (vout != Constants.VOUT_INDEX_TAPTREE) {
            revert IncorrectVout(vout, Constants.VOUT_INDEX_TAPTREE);
        }

        // Calculate the transaction hash for verification
        bytes32 txHash = bitcoinManager.getBtcTxHash(_pegOutTxSPVProof.btcTx);

        // Get the stream to check confirmations
        Stream memory stream = streamManager.getStreamById(streamInfo.streamId);

        // Verify the txHash is part of the Merkle Root and has enough confirmations
        verifyTxConfirmations(
            stream.pegOutConfirmations,
            txHash,
            _pegOutTxSPVProof.blockHash,
            _pegOutTxSPVProof.merkleBranchPath,
            _pegOutTxSPVProof.merkleBranchHashes
        );

        // Validate that the first output is a P2WPKH paying the user
        bytes memory userPubKey = pegOutTempInfo[acceptPegInTxHash].userPubKey;
        bitcoinManager.validatePegOutUserOutput(_pegOutTxSPVProof.btcTx.outputs[0], userPubKey);

        // Update slot status
        streamManager.paidSlot(
            streamInfo.streamId, streamInfo.packetNumber, streamInfo.slotId, acceptPegInTxHash, txHash
        );

        // update the peg status to PAID
        streamPosition[acceptPegInTxHash].pegStatus = PegStatus.PAID;

        emit PegOutRegistered(
            _pegOutTxSPVProof.blockHash,
            txHash,
            acceptPegInTxHash,
            streamInfo.streamId,
            streamInfo.packetNumber,
            streamInfo.slotId
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

    function getStreamPosition(bytes32 _btcTxHash) public view returns (StreamPosition memory) {
        return streamPosition[pegInRequests[_btcTxHash]];
    }

    function storePegOutAndInitSignatures(
        bytes32 _pegOutSignatureHash,
        uint64 _streamId,
        uint64 _packetNumber,
        uint64 _slotId
    ) internal {
        // Store the peg-out transaction hash on-chain and initialize the signatures
        bytes32 key = keccak256(abi.encodePacked(_streamId, _packetNumber, _slotId));
        pegOutSighashes[key] = _pegOutSignatureHash;

        // Get the committee key
        uint256 committeeId = streamManager.getCommitteeId(_streamId, _packetNumber);

        // Initialize the signatures for each member
        signatureManager.initSignatures(_pegOutSignatureHash, committeeId);
    }
}
