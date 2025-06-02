// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {BaseProxy} from "./BaseProxy.sol";
import {ICommitteeRegistry} from "./interfaces/ICommitteeRegistry.sol";
import {ISignatureManager} from "./interfaces/ISignatureManager.sol";
import {PrevoutData, BtcTransaction, BtcTxOut, IBitcoinManager} from "./interfaces/IBitcoinManager.sol";
import {
    BtcTxSPVProof,
    RequestPegInTempInfo,
    PegOutInfo,
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

    mapping(bytes32 requestPegInTxHash => StreamPosition streamPosition) internal pegInRequests;
    // Request PegIn Tx Hash => PegIn Temp Info (streamId, packetNumber, rskDestinationAddress)
    mapping(bytes32 requestPegInTxHash => RequestPegInTempInfo tempInfo) internal pegInTempInfo;

    // key = keccak256(abi.encodePacked(streamId, packetNumber, slotId))
    mapping(bytes32 key => bytes32 pegOutSignatureHash) internal pegOutSighashes;

    // Mapping from accept peg-in transaction hash to pegout info
    mapping(bytes32 acceptPegInTxHash => PegOutInfo pegOutInfo) internal pegOuts;

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

    function getPegInRequest(bytes32 _btcTxHash) external view returns (StreamPosition memory) {
        return pegInRequests[_btcTxHash];
    }

    function getRequestPegInTempInfo(bytes32 _btcTxHash) external view returns (RequestPegInTempInfo memory) {
        return pegInTempInfo[_btcTxHash];
    }

    function getPegOutInfo(bytes32 _pegOutTxHash) external view returns (PegOutInfo memory) {
        return pegOuts[_pegOutTxHash];
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
            stream.peginConfirmations,
            txHash,
            _pegInRequestTxSPVProof.blockHash,
            _pegInRequestTxSPVProof.merkleBranchPath,
            _pegInRequestTxSPVProof.merkleBranchHashes
        );

        // Store pegInRequest txHash to avoid processing it again
        pegInRequests[txHash] = StreamPosition({
            streamId: stream.streamId,
            packetNumber: packetNumber,
            slotId: 0,
            pegStatus: PegStatus.REGISTERED
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

        _initAcceptPegin(
            committeePubKey,
            btcReimbursementPubKey,
            txHash,
            rskDestinationAddress,
            PrevoutData({
                value: _pegInRequestTxSPVProof.btcTx.outputs[Constants.VOUT_INDEX_TAPTREE].amount,
                scriptPubKey: _pegInRequestTxSPVProof.btcTx.outputs[Constants.VOUT_INDEX_TAPTREE].scriptPubKey
            })
        );
    }

    function _initAcceptPegin(
        bytes32 _committeePubKey,
        bytes32 _userXOnlyPubKey,
        bytes32 _registerPegInTx,
        address _rskDestinationAddress,
        PrevoutData memory _prevoutData
    ) internal {
        // Compute the Bitcoin accept peg-in transaction signature hash
        (bytes32 acceptPeginTxHash, bytes32 acceptPeginSignatureHash, bytes memory acceptPeginSignatureMessage) =
        bitcoinManager.getAcceptPegInSignatureHash(_committeePubKey, _userXOnlyPubKey, _registerPegInTx, _prevoutData);

        // Store pegIn info needed for acceptPegIn
        pegInTempInfo[_registerPegInTx] = RequestPegInTempInfo({
            rskDestinationAddress: _rskDestinationAddress,
            btcReimbursementPubKey: _userXOnlyPubKey,
            acceptPeginSignatureHash: acceptPeginSignatureHash,
            acceptPeginTxHash: acceptPeginTxHash
        });

        emit InitAcceptPegin(_committeePubKey, _registerPegInTx, acceptPeginSignatureHash, acceptPeginSignatureMessage);

        // Initialize the signatures needed for a given aggregated key
        signatureManager.initSignatures(acceptPeginSignatureHash, _committeePubKey);
    }

    function acceptPegInRequest(BtcTxSPVProof calldata _pegInAcceptedTxSPVProof) external {
        // The first input consumes the the peg in request utxo
        bytes32 requestPegInTxHash = _pegInAcceptedTxSPVProof.btcTx.inputs[Constants.VOUT_INDEX_TAPTREE].txId;

        // Get the peg in request temp info
        RequestPegInTempInfo storage requestTempInfo = pegInTempInfo[requestPegInTxHash];

        // Validate the peg in request tx exists and the status
        StreamPosition storage streamPosition = pegInRequests[requestPegInTxHash];
        if (streamPosition.pegStatus == PegStatus.NOT_REGISTERED) {
            revert UnregisteredPegInRequest(requestPegInTxHash);
        }
        if (streamPosition.pegStatus != PegStatus.REGISTERED) {
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
            streamManager.getStreamById(streamPosition.streamId).peginConfirmations,
            txHash,
            _pegInAcceptedTxSPVProof.blockHash,
            _pegInAcceptedTxSPVProof.merkleBranchPath,
            _pegInAcceptedTxSPVProof.merkleBranchHashes
        );

        _storePegInAndInitSignatures(
            requestPegInTxHash,
            streamPosition,
            requestTempInfo,
            _pegInAcceptedTxSPVProof.blockHash,
            txHash,
            _pegInAcceptedTxSPVProof.btcTx.outputs[Constants.VOUT_INDEX_TAPTREE]
        );
    }

    function _storePegInAndInitSignatures(
        bytes32 _requestPegInTxHash,
        StreamPosition storage streamPosition,
        RequestPegInTempInfo storage requestTempInfo,
        bytes32 _blockHash,
        bytes32 _txHash,
        BtcTxOut memory _acceptPeginTxOutput
    ) internal {
        // Update the peg in request status to ACCEPTED to avoid processing it again
        streamPosition.pegStatus = PegStatus.ACCEPTED;
        // Store Tx in pegInSlot as Filled
        streamPosition.slotId = streamManager.fillAcceptPegInTx(
            streamPosition.streamId,
            streamPosition.packetNumber,
            _acceptPeginTxOutput.amount,
            _txHash,
            _acceptPeginTxOutput.scriptPubKey
        );

        // Check if we need a new packet
        if (streamPosition.slotId == Constants.SLOT_USAGE_THRESHOLD - 1) {
            bytes32 committeePubKey = committeeRegistry.selectCommittee(streamPosition.streamId);
            streamManager.createNewPacket(streamPosition.streamId, committeePubKey);
        }

        uint256 rbtcAmount = BtcHelper.satoshiToWei(_acceptPeginTxOutput.amount);

        emit AcceptedPegInRequest(
            _blockHash,
            _txHash,
            _requestPegInTxHash,
            Constants.VOUT_INDEX_TAPTREE,
            streamPosition,
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

        // Compute the Bitcoin peg-out transaction hash and signature hash
        (bytes32 pegOutSignatureHash, bytes memory commonSignatureMessage) =
            bitcoinManager.getPegOutSignatureHash(_usrPubKey, slot.acceptPegInTx, prevoutData);

        // Store the pegout transaction info for efficient lookup during registration
        pegOuts[slot.acceptPegInTx] = PegOutInfo({
            userPubKey: _usrPubKey,
            streamId: stream.streamId,
            packetNumber: packetNumber,
            slotId: slot.slotId,
            acceptPegInTxHash: slot.acceptPegInTx
        });

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

        // Look up the pegout transaction info using the accept peg-in transaction hash
        PegOutInfo memory pegOutInfo = pegOuts[acceptPegInTxHash];

        // Get the slot and validate it's LOCKED
        Slot memory slot = streamManager.getSlot(pegOutInfo.streamId, pegOutInfo.packetNumber, pegOutInfo.slotId);
        if (slot.state != SlotState.LOCKED) {
            revert InvalidSlotState(slot.state, SlotState.LOCKED);
        }

        // Validate that the first input references the correct accept peg-in transaction
        if (slot.acceptPegInTx != acceptPegInTxHash) {
            revert InvalidAcceptPegInTxHash(slot.acceptPegInTx, acceptPegInTxHash);
        }

        // Validate that the vout is correct
        if (vout != Constants.VOUT_INDEX_TAPTREE) {
            revert IncorrectVout(vout, Constants.VOUT_INDEX_TAPTREE);
        }

        // Calculate the transaction hash for verification
        bytes32 txHash = bitcoinManager.getBtcTxHash(_pegOutTxSPVProof.btcTx);

        // Get the stream to check confirmations
        Stream memory stream = streamManager.getStreamById(pegOutInfo.streamId);

        // Verify the txHash is part of the Merkle Root and has enough confirmations
        verifyTxConfirmations(
            stream.pegOutConfirmations,
            txHash,
            _pegOutTxSPVProof.blockHash,
            _pegOutTxSPVProof.merkleBranchPath,
            _pegOutTxSPVProof.merkleBranchHashes
        );

        // Validate that the first output is a P2WPKH paying the user
        _validatePegOutUserOutput(_pegOutTxSPVProof.btcTx.outputs[0], pegOutInfo.userPubKey);

        // Update slot status
        _markSlotAsPaid(pegOutInfo.streamId, pegOutInfo.packetNumber, pegOutInfo.slotId);

        emit PegOutRegistered(
            _pegOutTxSPVProof.blockHash,
            txHash,
            acceptPegInTxHash,
            pegOutInfo.streamId,
            pegOutInfo.packetNumber,
            pegOutInfo.slotId
        );
    }

    function _markSlotAsPaid(uint64 _streamId, uint64 _packetNumber, uint64 _slotId) internal {
        // Mark the slot as PAID in the StreamManager
        streamManager.markSlotAsPaid(_streamId, _packetNumber, _slotId);
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
        bytes32 _pegOutSignatureHash,
        uint64 _streamId,
        uint64 _packetNumber,
        uint64 _slotId
    ) internal {
        // Store the peg-out transaction hash on-chain and initialize the signatures
        bytes32 key = keccak256(abi.encodePacked(_streamId, _packetNumber, _slotId));
        pegOutSighashes[key] = _pegOutSignatureHash;

        // Get the committee key
        bytes32 committeeKey = streamManager.getCommitteePubKey(_streamId, _packetNumber);

        // Initialize the signatures for each member
        signatureManager.initSignatures(_pegOutSignatureHash, committeeKey);
    }

    function _validatePegOutUserOutput(BtcTxOut memory _userOutput, bytes memory _userPubKey) internal pure {
        bytes memory expectedScriptPubKey = BtcScriptParser.getP2WPKHScript(_userPubKey);

        // Validate that the output script matches the expected P2WPKH script
        if (!BytesHelper.compare(_userOutput.scriptPubKey, expectedScriptPubKey)) {
            revert IncorrectOutputScript(_userOutput.scriptPubKey, expectedScriptPubKey);
        }
    }
}
