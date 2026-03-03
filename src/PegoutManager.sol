// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {PegManagerBase} from "./PegManagerBase.sol";
import {IPegoutManager, PegoutRequest, PegoutStartInfo} from "./interfaces/IPegoutManager.sol";
import {ICommitteeRegistry} from "./interfaces/ICommitteeRegistry.sol";
import {ISignatureManager} from "./interfaces/ISignatureManager.sol";
import {IStreamManager, Stream, Slot} from "./interfaces/IStreamManager.sol";
import {IBitcoinManager, PrevoutData, BitcoinSignatureData} from "./interfaces/IBitcoinManager.sol";
import {BtcTxSPVProof, StreamPosition, PegStatus} from "./interfaces/IPegCommonTypes.sol";
import {BtcHelper} from "./libraries/BtcHelper.sol";
import {Constants} from "./libraries/Constants.sol";
import {IRbtcBridge} from "./interfaces/IRbtcBridge.sol";

/// @title PegoutManager
/// @notice Manages peg-out operations from Rootstock to Bitcoin
contract PegoutManager is IPegoutManager, PegManagerBase {
    mapping(bytes32 acceptPeginTxid => PegoutStartInfo startInfo) internal pegoutStartInfo;

    mapping(uint64 streamId => PegoutRequest[]) internal pegoutQueue;
    mapping(uint64 streamId => uint64) internal currentPegoutQueuePointer;

    /// @notice Initializes the PegManager contract
    /// @param _initialOwner The initial owner of the contract
    /// @param _accessManager The access manager contract address
    /// @param _committeeRegistry The committee registry contract address
    /// @param _bitcoinManager The Bitcoin manager contract address
    /// @param _rbtcBridge The RbtcBridge contract for burning RBTC
    /// @param _streamManager The stream manager contract address
    /// @param _signatureManager The signature manager contract address
    /// @dev This function can only be called once during contract deployment
    function initialize(
        address _initialOwner,
        address _accessManager,
        ICommitteeRegistry _committeeRegistry,
        IBitcoinManager _bitcoinManager,
        IRbtcBridge _rbtcBridge,
        IStreamManager _streamManager,
        ISignatureManager _signatureManager
    ) public virtual initializer {
        __PegManagerBase_init(
            _initialOwner,
            _accessManager,
            _committeeRegistry,
            _bitcoinManager,
            _rbtcBridge,
            _streamManager,
            _signatureManager
        );
    }

    /// @inheritdoc IPegoutManager
    function getPegoutStartInfo(bytes32 _acceptPeginTxid) external view returns (PegoutStartInfo memory pegoutInfo) {
        pegoutInfo = pegoutStartInfo[_acceptPeginTxid];
        // slither-disable-next-line timestamp
        if (pegoutInfo.pegoutTxid == bytes32(0)) {
            revert PegoutNotFoundForPegin(_acceptPeginTxid);
        }
    }

    function _validatePegoutRequest(bytes memory _userPubKey, uint256 _amountInWei)
        internal
        view
        returns (Stream memory stream, uint64 queueLength)
    {
        uint256 amountInSatoshi = BtcHelper.weiToSatoshi(_amountInWei);
        if (amountInSatoshi > type(uint64).max) {
            revert PegoutRequestAmountExceedsUint64Limit(amountInSatoshi);
        }

        // Validate the _userPubKey is 33 bytes (compressed pubkey)
        if (_userPubKey.length != 33 || (_userPubKey[0] != 0x02 && _userPubKey[0] != 0x03)) {
            revert InvalidCompressedPubKey(_userPubKey);
        }

        stream = streamManager.getStream(uint64(amountInSatoshi));
        queueLength = _getPegoutQueueLength(stream.streamId);
    }

    /// @inheritdoc IPegoutManager
    function enqueuePegout(bytes memory _userPubKey) external payable nonReentrant whenNotPaused {
        (Stream memory stream, uint64 queueLength) = _validatePegoutRequest(_userPubKey, msg.value);

        if (queueLength >= Constants.MAX_PEGOUT_QUEUE_SIZE) {
            revert PegoutQueueFull(stream.streamId);
        }

        uint64 filledSlotsCount = streamManager.getFilledSlotsCount(stream.streamId);
        if (queueLength >= filledSlotsCount) {
            revert NoFreeFilledSlot(stream.streamId, queueLength, filledSlotsCount);
        }

        // Enqueue the pegout request
        pegoutQueue[stream.streamId].push(PegoutRequest({userPubKey: _userPubKey, userAddress: msg.sender}));
        emit PegoutEnqueued(stream.streamId, _userPubKey, msg.sender);
    }

    /// @inheritdoc IPegoutManager
    function dequeuePegout(uint64 _streamId) external nonReentrant whenNotPaused {
        // Check if there are any enqueued peg-out requests for the given stream ID. If not, revert with an error.
        if (_getPegoutQueueLength(_streamId) == 0) {
            revert NoEnqueuedPegout(_streamId);
        }

        address sender = _msgSender();
        bool userPegoutFound = false;
        // slither-disable-next-line uninitialized-local
        PegoutRequest memory request;
        uint64 queueLength = uint64(pegoutQueue[_streamId].length);

        uint64 i = currentPegoutQueuePointer[_streamId];

        // Iterate through the peg-out queue to find the user's request
        for (; i < queueLength; i++) {
            address pegoutUserAddress = pegoutQueue[_streamId][i].userAddress;
            if (pegoutUserAddress == sender) {
                request = pegoutQueue[_streamId][i];
                userPegoutFound = true;
                break;
            }
        }

        if (!userPegoutFound) {
            revert PegoutNotFoundInQueue(_streamId, sender);
        }

        // Shift the remaining peg-out requests forward in the queue to fill the gap left by the dequeued request
        for (; i < queueLength - 1; i++) {
            pegoutQueue[_streamId][i] = pegoutQueue[_streamId][i + 1];
        }

        pegoutQueue[_streamId].pop();
        // Emit an event for the dequeued peg-out request
        emit PegoutDequeued(_streamId, request.userPubKey, sender);

        // Refund the user for the dequeued peg-out request
        uint256 amountInWei = BtcHelper.satoshiToWei(((streamManager.getStreamById(_streamId).denomination)));
        // slither-disable-next-line arbitrary-send-eth
        (bool sent,) = payable(sender).call{value: amountInWei}("");

        // If the transfer fails, revert with an error
        if (!sent) {
            revert FailedToSendRSK(sender, amountInWei);
        }
    }

    /// @inheritdoc IPegoutManager
    function getPegoutQueueLength(uint64 _streamId) external view returns (uint64) {
        return _getPegoutQueueLength(_streamId);
    }

    function _getPegoutQueueLength(uint64 _streamId) internal view returns (uint64) {
        return uint64(pegoutQueue[_streamId].length) - currentPegoutQueuePointer[_streamId];
    }

    // Get the next enqueued pegout to process and advance the queue pointer
    function _popPegoutQueue(uint64 _streamId) internal returns (PegoutRequest memory request) {
        if (_getPegoutQueueLength(_streamId) == 0) {
            revert NoEnqueuedPegout(_streamId);
        }

        request = pegoutQueue[_streamId][currentPegoutQueuePointer[_streamId]];
        currentPegoutQueuePointer[_streamId]++;
    }

    /// @inheritdoc IPegoutManager
    function tryProcessEnqueuedPegout(uint64 _streamId) external nonReentrant whenNotPaused {
        PegoutRequest memory request = _popPegoutQueue(_streamId);
        // Emit an event for the dequeued peg-out request
        emit PegoutDequeued(_streamId, request.userPubKey, request.userAddress);

        Stream memory stream = streamManager.getStreamById(_streamId);
        _processPegout(request.userPubKey, stream);
    }

    function _processPegout(bytes memory _userPubKey, Stream memory _stream) internal {
        // slither-disable-next-line reentrancy-benign
        (Slot memory slot, uint64 packetNumber) = streamManager.lockSlot(_stream.streamId);

        PrevoutData[] memory prevoutDatas = _preparePegoutPrevoutDatas(_stream.streamId, packetNumber, slot);

        // Compute the Bitcoin peg-out signature hash
        BitcoinSignatureData memory pegoutSignatureData =
            bitcoinManager.getPegoutTxData(_userPubKey, slot.acceptPeginTx, prevoutDatas);

        uint128 committeeId =
            _storePegoutAndInitSignatures(pegoutSignatureData.txid, _stream.streamId, packetNumber, slot.slotId);

        pegoutStartInfo[slot.acceptPeginTx] =
            PegoutStartInfo({userPubKey: _userPubKey, createdAt: block.timestamp, pegoutTxid: pegoutSignatureData.txid});

        // slither-disable-next-line reentrancy-events
        emit PegoutRequested(
            _userPubKey,
            committeeId,
            pegoutSignatureData,
            _stream.streamId,
            packetNumber,
            slot.slotId,
            _stream.denomination
        );

        streamManager.setPegStatus(slot.acceptPeginTx, PegStatus.USER_TAKE);

        // Burn RBTC back to PowPeg bridge via RbtcBridge
        // We burn the amount that was actually minted (acceptPeginAmount), not msg.value
        // The difference (fees) remains in the contract for future operator fee distribution
        uint256 amountToBurn = BtcHelper.satoshiToWei(slot.acceptPeginAmount);
        rbtcBridge.burnRbtc{value: amountToBurn}();
    }

    /// @inheritdoc IPegoutManager
    function tryPegout(bytes memory _userPubKey) external payable nonReentrant whenNotPaused {
        (Stream memory stream, uint64 queueLength) = _validatePegoutRequest(_userPubKey, msg.value);

        if (queueLength > 0) {
            revert EnqueuedPegoutsForStream(stream.streamId, queueLength);
        }

        _processPegout(_userPubKey, stream);
    }

    /// @inheritdoc IPegoutManager
    function registerUserTake(BtcTxSPVProof memory _pegoutTxSPVProof) external nonReentrant whenNotPaused {
        // Get the accept peg-in tx id from the first input (this is what gets spent)
        bytes32 acceptPeginTxid = _pegoutTxSPVProof.btcTx.inputs[Constants.PEGOUT_VIN_TAPTREE].txId;
        uint32 vout = _pegoutTxSPVProof.btcTx.inputs[Constants.PEGOUT_VIN_TAPTREE].vout;

        // get the stream data for this pegout
        (StreamPosition memory streamInfo, uint128 committeeId, uint8 pegoutConfirmations) =
            streamManager.validatePegoutStatus(acceptPeginTxid, PegStatus.USER_TAKE);

        // Validate that the vout is correct
        if (vout != Constants.ACCEPT_PEGIN_VOUT_TAPTREE) {
            revert IncorrectVout(vout, Constants.ACCEPT_PEGIN_VOUT_TAPTREE);
        }

        // Calculate the transaction id for verification
        bytes32 pegoutRequestTxid = bitcoinManager.getBtcTxid(_pegoutTxSPVProof.btcTx);

        // Verify the PegoutRequestTxid is part of the Merkle Root and has enough confirmations
        rbtcBridge.verifyTxConfirmations(
            pegoutConfirmations,
            pegoutRequestTxid,
            _pegoutTxSPVProof.blockHash,
            _pegoutTxSPVProof.merkleBranchPath,
            _pegoutTxSPVProof.merkleBranchHashes
        );

        // Validate that the first output is a P2WPKH paying the user
        bitcoinManager.validatePegoutUserOutput(
            _pegoutTxSPVProof.btcTx.outputs[Constants.PEGOUT_VOUT_USER], pegoutStartInfo[acceptPeginTxid].userPubKey
        );

        emit PegoutRegistered(_pegoutTxSPVProof.blockHash, pegoutRequestTxid, acceptPeginTxid, committeeId, streamInfo);
        _completeSlot(streamInfo, acceptPeginTxid, pegoutRequestTxid);
    }

    function _storePegoutAndInitSignatures(bytes32 _pegoutTxid, uint64 _streamId, uint64 _packetNumber, uint64 _slotId)
        internal
        returns (uint128)
    {
        // Get the committee id
        uint128 committeeId = streamManager.getCommitteeId(_streamId, _packetNumber);

        // Initialize the signatures for each member using txid
        signatureManager.initSignatures(_pegoutTxid, committeeId);

        return committeeId;
    }

    function _preparePegoutPrevoutDatas(uint64 _streamId, uint64 _packetNumber, Slot memory _slot)
        internal
        view
        returns (PrevoutData[] memory)
    {
        PrevoutData[] memory prevoutDatas = new PrevoutData[](2);

        // Taptree prevout - read from slot
        prevoutDatas[0] = PrevoutData({value: _slot.acceptPeginAmount, scriptPubKey: _slot.scriptPubKey});

        // Enabler prevout - read from packet
        prevoutDatas[1] = PrevoutData({
            value: Constants.ENABLER_AMOUNT,
            scriptPubKey: streamManager.getEnablerScriptPubKey(_streamId, _packetNumber)
        });

        return prevoutDatas;
    }
}
