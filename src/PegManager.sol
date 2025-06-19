// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {BaseProxy} from "./BaseProxy.sol";
import {ICommitteeRegistry} from "./interfaces/ICommitteeRegistry.sol";
import {ISignatureManager} from "./interfaces/ISignatureManager.sol";
import {PrevoutData, BtcTransaction, BtcTxOut, IBitcoinManager} from "./interfaces/IBitcoinManager.sol";
import {
    BtcTxSPVProof,
    RequestPeginTempInfo,
    PegoutTempInfo,
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

    mapping(bytes32 requestPeginTxHash => bytes32 acceptPeginTxhash) internal peginRequests;
    mapping(bytes32 acceptPeginTxhash => StreamPosition streamPosition) internal streamPosition;
    mapping(bytes32 requestPeginTxHash => RequestPeginTempInfo tempInfo) internal peginTempInfo;
    mapping(bytes32 acceptPeginTxHash => PegoutTempInfo tempInfo) internal pegoutTempInfo;

    // key = keccak256(abi.encodePacked(streamId, packetNumber, slotId))
    mapping(bytes32 key => bytes32 pegoutSignatureHash) internal pegoutSighashes;

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

    function getPeginRequest(bytes32 _btcTxHash) external view returns (bytes32) {
        return peginRequests[_btcTxHash];
    }

    function getRequestPeginTempInfo(bytes32 _btcTxHash) external view returns (RequestPeginTempInfo memory) {
        return peginTempInfo[_btcTxHash];
    }

    function getPegoutTempInfo(bytes32 _acceptPeginTxHash) external view returns (PegoutTempInfo memory) {
        return pegoutTempInfo[_acceptPeginTxHash];
    }

    function getTemporaryPeginAddress(address _rootstockDepositAddress, uint64 _value, bytes32 _btcReimbursementPubKey)
        external
        view
        returns (string memory bitcoinDepositAddress)
    {
        // Get the stream for this value
        Stream memory stream = streamManager.getStream(_value);

        // Get the current packet's committee key
        Packet memory currentPacket = streamManager.getPacket(stream.streamId, stream.peginPacketPointer);
        bytes32 committeeKey = currentPacket.committeePubKey;

        return bitcoinManager.getTemporaryPeginAddress(
            _rootstockDepositAddress, _value, _btcReimbursementPubKey, committeeKey
        );
    }

    function requestPegin(BtcTxSPVProof calldata _peginRequestTxSPVProof) external {
        if (_peginRequestTxSPVProof.btcTx.version != Constants.BTC_TX_VERSION) {
            revert InvalidBtcTxVersion(_peginRequestTxSPVProof.btcTx.version, Constants.BTC_TX_VERSION);
        }
        if (_peginRequestTxSPVProof.btcTx.locktime != Constants.LOCKTIME) {
            revert InvalidLocktime(_peginRequestTxSPVProof.btcTx.locktime, Constants.LOCKTIME);
        }
        // Calculate txHash from BtcTransaction
        bytes32 txHash = bitcoinManager.getBtcTxHash(_peginRequestTxSPVProof.btcTx);
        if (getStreamPosition(txHash).pegStatus != PegStatus.NOT_REGISTERED) {
            revert PeginAlreadyRequested(txHash);
        }
        // Validate transaction has at least 2 outputs
        if (_peginRequestTxSPVProof.btcTx.outputs.length < 2) {
            revert IncorrectOutputsNumber(uint64(_peginRequestTxSPVProof.btcTx.outputs.length), 2);
        }
        // Second transaction should be OP_RETURN with data
        (uint64 packetNumber, address rskDestinationAddress, bytes32 btcReimbursementPubKey) =
            bitcoinManager.getPeginOpReturnData(_peginRequestTxSPVProof.btcTx.outputs[Constants.VOUT_INDEX_SPEED_UP]);
        // First transaction is the Pegin P2TR _peginRequestTxSPVProof.btcTx.outputs[0]
        // Get corresponding stream for the amount if non found reverts
        Stream memory stream =
            streamManager.getStream(_peginRequestTxSPVProof.btcTx.outputs[Constants.VOUT_INDEX_TAPTREE].amount);

        // getCommitteePubKey reverts if packet does not exist
        bytes32 committeePubKey = streamManager.getCommitteePubKey(stream.streamId, packetNumber);

        // Validates that the Taproot Script has a Key Path for the committeePubKey
        // and has a timelock for btcReimbursementPubKey
        bitcoinManager.validatRequestPeginP2TROutput(
            rskDestinationAddress,
            stream.denomination,
            btcReimbursementPubKey,
            committeePubKey,
            _peginRequestTxSPVProof.btcTx.outputs[Constants.VOUT_INDEX_TAPTREE]
        );

        // Verify the txHash part of the Merkle Root of Tx of a Block
        // and that block is inside Bitcoin Mainchain
        // and has enough confirmations
        verifyTxConfirmations(
            stream.peginConfirmations,
            txHash,
            _peginRequestTxSPVProof.blockHash,
            _peginRequestTxSPVProof.merkleBranchPath,
            _peginRequestTxSPVProof.merkleBranchHashes
        );

        emit PeginRequested(
            _peginRequestTxSPVProof.blockHash,
            txHash,
            Constants.VOUT_INDEX_TAPTREE, // vout is the first output, is the P2TR
            stream.denomination,
            packetNumber,
            rskDestinationAddress,
            btcReimbursementPubKey,
            _peginRequestTxSPVProof.btcTx.outputs[Constants.VOUT_INDEX_TAPTREE].scriptPubKey
        );

        _initAcceptPegin(
            committeePubKey,
            btcReimbursementPubKey,
            txHash,
            rskDestinationAddress,
            PrevoutData({
                value: _peginRequestTxSPVProof.btcTx.outputs[Constants.VOUT_INDEX_TAPTREE].amount,
                scriptPubKey: _peginRequestTxSPVProof.btcTx.outputs[Constants.VOUT_INDEX_TAPTREE].scriptPubKey
            }),
            stream.streamId,
            packetNumber
        );
    }

    function _initAcceptPegin(
        bytes32 _committeePubKey,
        bytes32 _userXOnlyPubKey,
        bytes32 _registerPeginTx,
        address _rskDestinationAddress,
        PrevoutData memory _prevoutData,
        uint64 _streamId,
        uint64 _packetNumber
    ) internal {
        // Compute the Bitcoin accept peg-in transaction signature hash
        (bytes32 acceptPeginTxHash, bytes32 acceptPeginSignatureHash, bytes memory acceptPeginSignatureMessage) =
        bitcoinManager.getAcceptPeginSignatureHash(_committeePubKey, _userXOnlyPubKey, _registerPeginTx, _prevoutData);

        // Store peginRequest txHash to avoid processing it again
        peginRequests[_registerPeginTx] = acceptPeginTxHash;
        streamPosition[acceptPeginTxHash] = StreamPosition({
            streamId: _streamId,
            packetNumber: _packetNumber,
            slotId: 0,
            pegStatus: PegStatus.REGISTERED
        });

        // Store pegin info needed for acceptPegin
        peginTempInfo[_registerPeginTx] = RequestPeginTempInfo({
            rskDestinationAddress: _rskDestinationAddress,
            btcReimbursementPubKey: _userXOnlyPubKey,
            acceptPeginSignatureHash: acceptPeginSignatureHash,
            acceptPeginTxHash: acceptPeginTxHash
        });

        emit InitAcceptPegin(
            _committeePubKey, _registerPeginTx, acceptPeginTxHash, acceptPeginSignatureHash, acceptPeginSignatureMessage
        );

        // Initialize the signatures needed for a given aggregated key
        uint256 committeeId = streamManager.getCommitteeId(_streamId, _packetNumber);
        signatureManager.initSignatures(acceptPeginSignatureHash, committeeId);
        signatureManager.initTake1TxHashes(acceptPeginTxHash, committeeId);
    }

    function acceptPegin(BtcTxSPVProof calldata _peginAcceptedTxSPVProof) external {
        // The first input consumes the the peg in request utxo
        bytes32 requestPeginTxHash = _peginAcceptedTxSPVProof.btcTx.inputs[Constants.VOUT_INDEX_TAPTREE].txId;

        // Get the peg in request temp info
        RequestPeginTempInfo storage requestTempInfo = peginTempInfo[requestPeginTxHash];

        // Validate the peg in request tx exists and the status
        StreamPosition memory streamInfo = getStreamPosition(requestPeginTxHash);
        if (streamInfo.pegStatus == PegStatus.NOT_REGISTERED) {
            revert PeginNotRequested(requestPeginTxHash);
        }
        if (streamInfo.pegStatus != PegStatus.REGISTERED) {
            revert PeginAlreadyAccepted(requestPeginTxHash);
        }

        // Calculate acceptPegintxHash from BtcTransaction
        bytes32 acceptPegintxHash = bitcoinManager.getBtcTxHash(_peginAcceptedTxSPVProof.btcTx);

        // Validate the txhash is the same calculated at request peg in tx
        if (requestTempInfo.acceptPeginTxHash != acceptPegintxHash) {
            revert InvalidAcceptPeginTxHash(requestTempInfo.acceptPeginTxHash, acceptPegintxHash);
        }

        // Verify the acceptPegintxHash part of the Merkle Root of Tx of a Block
        // and that block is inside Bitcoin Mainchain
        // annd has enough confirmations
        verifyTxConfirmations(
            streamManager.getStreamById(streamInfo.streamId).peginConfirmations,
            acceptPegintxHash,
            _peginAcceptedTxSPVProof.blockHash,
            _peginAcceptedTxSPVProof.merkleBranchPath,
            _peginAcceptedTxSPVProof.merkleBranchHashes
        );

        _storePegin(
            requestPeginTxHash,
            streamInfo,
            requestTempInfo,
            _peginAcceptedTxSPVProof.blockHash,
            acceptPegintxHash,
            _peginAcceptedTxSPVProof.btcTx.outputs[Constants.VOUT_INDEX_TAPTREE]
        );
    }

    function _storePegin(
        bytes32 _requestPeginTxHash,
        StreamPosition memory streamInfo,
        RequestPeginTempInfo storage requestTempInfo,
        bytes32 _blockHash,
        bytes32 _acceptPegintxHash,
        BtcTxOut memory _acceptPeginTxOutput
    ) internal {
        StreamPosition storage stream = streamPosition[_acceptPegintxHash];

        // Update the peg in request status to ACCEPTED to avoid processing it again
        stream.pegStatus = PegStatus.ACCEPTED;

        // Store Tx in peginSlot as Filled
        stream.slotId = streamManager.fillAcceptPeginTx(
            streamInfo.streamId,
            streamInfo.packetNumber,
            _acceptPeginTxOutput.amount,
            _acceptPegintxHash,
            _acceptPeginTxOutput.scriptPubKey
        );

        // Check if we need a new packet/committee
        if (stream.slotId == Constants.SLOT_USAGE_THRESHOLD - 1) {
            committeeRegistry.createCommittee(stream.streamId);
        }

        if (stream.slotId >= Constants.SLOT_USAGE_THRESHOLD) {
            if (committeeRegistry.isPendingCommitteeExpired(stream.streamId)) {
                committeeRegistry.createCommittee(stream.streamId);
            }
        }

        uint256 rbtcAmount = BtcHelper.satoshiToWei(_acceptPeginTxOutput.amount);

        emit PeginAccepted(
            _blockHash,
            _acceptPegintxHash,
            _requestPeginTxHash,
            Constants.VOUT_INDEX_TAPTREE,
            stream,
            requestTempInfo.btcReimbursementPubKey,
            requestTempInfo.rskDestinationAddress,
            rbtcAmount,
            _acceptPeginTxOutput.scriptPubKey
        );

        // TODO mint the peg in tokens
        //requestRbtc(rskDestinationAddress, rbtcAmount);
    }

    function validatePegoutRequest(bytes calldata _usrPubKey, uint256 amountInWei) internal pure {
        if (BtcHelper.weiToSatoshi(amountInWei) > type(uint64).max) {
            revert PegoutRequestAmountExceedsUint64Limit(BtcHelper.weiToSatoshi(amountInWei));
        }

        // Validate the _usrPubKey is 33 bytes (compressed pubkey)
        if (_usrPubKey.length != 33 || (_usrPubKey[0] != 0x02 && _usrPubKey[0] != 0x03)) {
            revert InvalidCompressedPubKey(_usrPubKey);
        }

        // TODO: validate who can request a peg-out
    }

    function tryPegout(bytes calldata _usrPubKey) external payable {
        validatePegoutRequest(_usrPubKey, msg.value);

        uint64 receivedAmount = uint64(BtcHelper.weiToSatoshi(msg.value));

        // Get first filled Slot
        Stream memory stream = streamManager.getStream(receivedAmount);
        (Slot memory slot, uint64 packetNumber) = streamManager.lockSlot(stream.streamId);

        // Prepare prevout data
        PrevoutData memory prevoutData = PrevoutData({value: slot.acceptPeginAmount, scriptPubKey: slot.scriptPubKey});

        // Compute the Bitcoin peg-out signature hash
        (bytes32 pegoutSignatureHash, bytes memory pegoutSignatureMessage) =
            bitcoinManager.getPegoutSignatureHash(_usrPubKey, slot.acceptPeginTx, prevoutData);

        // Store the pegout transaction info for efficient lookup during registration
        pegoutTempInfo[slot.acceptPeginTx] = PegoutTempInfo({userPubKey: _usrPubKey});

        // Store the peg-out transaction hash on-chain and initialize the signatures
        uint256 committeeId =
            storePegoutAndInitSignatures(pegoutSignatureHash, stream.streamId, packetNumber, slot.slotId);

        // TODO: return RBTC to the RSK Legacy Bridge following https://github.com/rsksmart/RSKIPs/pull/502

        emit PegoutRequested(
            _usrPubKey,
            committeeId,
            pegoutSignatureHash,
            pegoutSignatureMessage,
            stream.streamId,
            packetNumber,
            slot.slotId,
            stream.denomination
        );
    }

    /// @notice Register a peg-out transaction from Bitcoin
    /// @param _pegoutTxSPVProof The BTC SPV proof of the peg-out transaction
    function registerPegout(BtcTxSPVProof calldata _pegoutTxSPVProof) external {
        // Get the accept peg-in tx hash from the first input (this is what gets spent)
        bytes32 acceptPeginTxHash = _pegoutTxSPVProof.btcTx.inputs[0].txId;
        uint32 vout = _pegoutTxSPVProof.btcTx.inputs[0].vout;

        // get the stream data for this pegout
        StreamPosition memory streamInfo = streamPosition[acceptPeginTxHash];

        if (streamInfo.pegStatus == PegStatus.NOT_REGISTERED) {
            revert PeginNotRequested(acceptPeginTxHash);
        }

        // Validate that the vout is correct
        if (vout != Constants.VOUT_INDEX_TAPTREE) {
            revert IncorrectVout(vout, Constants.VOUT_INDEX_TAPTREE);
        }

        // Calculate the transaction hash for verification
        bytes32 txHash = bitcoinManager.getBtcTxHash(_pegoutTxSPVProof.btcTx);

        // Get the stream to check confirmations
        Stream memory stream = streamManager.getStreamById(streamInfo.streamId);

        // Verify the txHash is part of the Merkle Root and has enough confirmations
        verifyTxConfirmations(
            stream.pegoutConfirmations,
            txHash,
            _pegoutTxSPVProof.blockHash,
            _pegoutTxSPVProof.merkleBranchPath,
            _pegoutTxSPVProof.merkleBranchHashes
        );

        // Validate that the first output is a P2WPKH paying the user
        bytes memory userPubKey = pegoutTempInfo[acceptPeginTxHash].userPubKey;
        bitcoinManager.validatePegoutUserOutput(_pegoutTxSPVProof.btcTx.outputs[0], userPubKey);

        // Update slot status
        streamManager.paidSlot(
            streamInfo.streamId, streamInfo.packetNumber, streamInfo.slotId, acceptPeginTxHash, txHash
        );

        // update the peg status to PAID
        streamPosition[acceptPeginTxHash].pegStatus = PegStatus.PAID;

        emit PegoutRegistered(
            _pegoutTxSPVProof.blockHash,
            txHash,
            acceptPeginTxHash,
            streamInfo.streamId,
            streamInfo.packetNumber,
            streamInfo.slotId
        );
    }

    function getPegoutSignatureHash(uint64 streamId, uint64 packetNumber, uint64 slotId)
        external
        view
        returns (bytes32)
    {
        bytes32 key = keccak256(abi.encodePacked(streamId, packetNumber, slotId));
        return pegoutSighashes[key];
    }

    function getStreamPosition(bytes32 _btcTxHash) public view returns (StreamPosition memory) {
        return streamPosition[peginRequests[_btcTxHash]];
    }

    function storePegoutAndInitSignatures(
        bytes32 _pegoutSignatureHash,
        uint64 _streamId,
        uint64 _packetNumber,
        uint64 _slotId
    ) internal returns (uint256) {
        // Store the peg-out transaction hash on-chain and initialize the signatures
        bytes32 key = keccak256(abi.encodePacked(_streamId, _packetNumber, _slotId));
        pegoutSighashes[key] = _pegoutSignatureHash;

        // Get the committee key
        uint256 committeeId = streamManager.getCommitteeId(_streamId, _packetNumber);

        // Initialize the signatures for each member
        signatureManager.initSignatures(_pegoutSignatureHash, committeeId);

        return committeeId;
    }
}
