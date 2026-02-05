// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {PegManagerBase} from "./PegManagerBase.sol";
import {IPegoutManager, PegoutManagerSettings, PegoutTempInfo} from "./interfaces/IPegoutManager.sol";
import {ICommitteeRegistry} from "./interfaces/ICommitteeRegistry.sol";
import {ISignatureManager, SignatureData, OperatorTakeData} from "./interfaces/ISignatureManager.sol";
import {IStreamManager, Stream, Slot} from "./interfaces/IStreamManager.sol";
import {IBitcoinManager, PrevoutData, BitcoinSignatureData} from "./interfaces/IBitcoinManager.sol";
import {BtcTxSPVProof, StreamPosition, PegStatus} from "./interfaces/IPegCommonTypes.sol";
import {BtcHelper} from "./libraries/BtcHelper.sol";
import {Constants} from "./libraries/Constants.sol";
import {IRbtcBridge} from "./interfaces/IRbtcBridge.sol";
import {ChallengeTempInfo, IChallengeManager} from "./interfaces/IChallengeManager.sol";

/// @title PegoutManager
/// @notice Manages peg-out operations from Rootstock to Bitcoin
contract PegoutManager is IPegoutManager, PegManagerBase {
    /// @notice Timeout in seconds for user take operations
    uint256 public userTakeTimeout;

    /// @notice Timeout in seconds for operator take operations
    uint256 public operatorTakeTimeout;

    mapping(bytes32 acceptPeginTxid => PegoutTempInfo tempInfo) internal pegoutTempInfo;

    mapping(bytes32 pegoutTxid => bytes32 acceptPeginTxid) internal pegoutToPeginTxid;

    // Key = keccak256(abi.encodePacked(streamId, packetNumber, slotId))
    mapping(bytes32 key => bytes32 pegoutTxid) internal pegoutTxids;

    /// @notice Initializes the PegManager contract
    /// @param _initialOwner The initial owner of the contract
    /// @param _accessManager The access manager contract address
    /// @param _committeeRegistry The committee registry contract address
    /// @param _bitcoinManager The Bitcoin manager contract address
    /// @param _rbtcBridge The RbtcBridge contract for burning RBTC
    /// @param _streamManager The stream manager contract address
    /// @param _signatureManager The signature manager contract address
    /// @param _settings The peg manager settings including timeouts
    /// @dev This function can only be called once during contract deployment
    function initialize(
        address _initialOwner,
        address _accessManager,
        ICommitteeRegistry _committeeRegistry,
        IBitcoinManager _bitcoinManager,
        IRbtcBridge _rbtcBridge,
        IStreamManager _streamManager,
        ISignatureManager _signatureManager,
        PegoutManagerSettings memory _settings
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

        // Validate that the settings are not zero
        if (_settings.userTakeTimeout == 0 || _settings.operatorTakeTimeout == 0) {
            revert InvalidTimeout(0);
        }

        userTakeTimeout = _settings.userTakeTimeout;
        operatorTakeTimeout = _settings.operatorTakeTimeout;
    }

    /// @inheritdoc IPegoutManager
    function getPegoutTempInfo(bytes32 _acceptPeginTxid) external view returns (PegoutTempInfo memory) {
        return pegoutTempInfo[_acceptPeginTxid];
    }

    /// @inheritdoc IPegoutManager
    function getAcceptPeginTxid(bytes32 _pegoutTxid) external view returns (bytes32) {
        return pegoutToPeginTxid[_pegoutTxid];
    }

    function _validatePegoutRequest(bytes memory _userPubKey, uint256 amountInWei) internal pure {
        if (BtcHelper.weiToSatoshi(amountInWei) > type(uint64).max) {
            revert PegoutRequestAmountExceedsUint64Limit(BtcHelper.weiToSatoshi(amountInWei));
        }

        // Validate the _userPubKey is 33 bytes (compressed pubkey)
        if (_userPubKey.length != 33 || (_userPubKey[0] != 0x02 && _userPubKey[0] != 0x03)) {
            revert InvalidCompressedPubKey(_userPubKey);
        }
    }

    /// @inheritdoc IPegoutManager
    function tryPegout(bytes memory _userPubKey) external payable nonReentrant whenNotPaused {
        _validatePegoutRequest(_userPubKey, msg.value);

        Stream memory stream = streamManager.getStream(uint64(BtcHelper.weiToSatoshi(msg.value)));
        // slither-disable-next-line reentrancy-benign
        (Slot memory slot, uint64 packetNumber) = streamManager.lockSlot(stream.streamId);

        PrevoutData[] memory prevoutDatas = _preparePegoutPrevoutDatas(stream.streamId, packetNumber, slot);

        // Compute the Bitcoin peg-out signature hash
        BitcoinSignatureData memory pegoutSignatureData =
            bitcoinManager.getPegoutTxData(_userPubKey, slot.acceptPeginTx, prevoutDatas);

        uint128 committeeId =
            _storePegoutAndInitSignatures(pegoutSignatureData.txid, stream.streamId, packetNumber, slot.slotId);

        // Store the pegout to pegin tx id mapping
        pegoutToPeginTxid[pegoutSignatureData.txid] = slot.acceptPeginTx;

        // Compute pegout ID
        bytes32 pegoutId = keccak256(
            abi.encode(stream.streamId, packetNumber, slot.slotId, _msgSender(), rbtcBridge.getBestBlockHash())
        );

        pegoutTempInfo[slot.acceptPeginTx] = PegoutTempInfo({
            userPubKey: _userPubKey,
            createdAt: block.timestamp,
            operatorTakeUpdatedAt: 0,
            committeeId: committeeId,
            takeOperatorAddress: address(0),
            operatorDisputePubKey: bytes32(0),
            pegoutId: pegoutId,
            advanceFundsBlockNumber: 0,
            reimbursementKickoffTxid: bytes32(0)
        });

        // slither-disable-next-line reentrancy-events
        emit PegoutRequested(
            _userPubKey,
            committeeId,
            pegoutSignatureData,
            stream.streamId,
            packetNumber,
            slot.slotId,
            stream.denomination,
            pegoutId
        );

        streamManager.setPegStatus(slot.acceptPeginTx, PegStatus.USER_TAKE);

        // Burn RBTC back to PowPeg bridge via RbtcBridge
        // We burn the amount that was actually minted (acceptPeginAmount), not msg.value
        // The difference (fees) remains in the contract for future operator fee distribution
        uint256 amountToBurn = BtcHelper.satoshiToWei(slot.acceptPeginAmount);
        rbtcBridge.burnRbtc{value: amountToBurn}();
    }

    /// @inheritdoc IPegoutManager
    function registerUserTake(BtcTxSPVProof memory _pegoutTxSPVProof) external nonReentrant whenNotPaused {
        // Get the accept peg-in tx id from the first input (this is what gets spent)
        bytes32 acceptPeginTxid = _pegoutTxSPVProof.btcTx.inputs[Constants.PEGOUT_VIN_TAPTREE].txId;
        uint32 vout = _pegoutTxSPVProof.btcTx.inputs[Constants.PEGOUT_VIN_TAPTREE].vout;

        // get the stream data for this pegout
        StreamPosition memory streamInfo = _validatePegStatus(acceptPeginTxid, PegStatus.USER_TAKE);

        // Validate that the vout is correct
        if (vout != Constants.ACCEPT_PEGIN_VOUT_TAPTREE) {
            revert IncorrectVout(vout, Constants.ACCEPT_PEGIN_VOUT_TAPTREE);
        }

        // Calculate the transaction id for verification
        bytes32 requestPegoutTxid = bitcoinManager.getBtcTxid(_pegoutTxSPVProof.btcTx);

        // Get the stream to check confirmations
        Stream memory stream = streamManager.getStreamById(streamInfo.streamId);

        // Verify the requestPegoutTxid is part of the Merkle Root and has enough confirmations
        rbtcBridge.verifyTxConfirmations(
            stream.pegoutConfirmations,
            requestPegoutTxid,
            _pegoutTxSPVProof.blockHash,
            _pegoutTxSPVProof.merkleBranchPath,
            _pegoutTxSPVProof.merkleBranchHashes
        );

        // Validate that the first output is a P2WPKH paying the user
        // bytes memory userPubKey = pegoutTempInfo[acceptPeginTxid].userPubKey;
        bitcoinManager.validatePegoutUserOutput(
            _pegoutTxSPVProof.btcTx.outputs[Constants.PEGOUT_VOUT_USER], pegoutTempInfo[acceptPeginTxid].userPubKey
        );

        // update the peg status to COMPLETED
        streamManager.setPegStatus(acceptPeginTxid, PegStatus.COMPLETED);

        emit PegoutRegistered(
            _pegoutTxSPVProof.blockHash,
            requestPegoutTxid,
            acceptPeginTxid,
            pegoutTempInfo[acceptPeginTxid].committeeId,
            streamInfo
        );
        _completeSlot(streamInfo, acceptPeginTxid, requestPegoutTxid);
    }

    /// @inheritdoc IPegoutManager
    function getPegoutTxid(uint64 streamId, uint64 packetNumber, uint64 slotId) external view returns (bytes32) {
        bytes32 key = keccak256(abi.encodePacked(streamId, packetNumber, slotId));
        return pegoutTxids[key];
    }

    function _storePegoutAndInitSignatures(bytes32 _pegoutTxid, uint64 _streamId, uint64 _packetNumber, uint64 _slotId)
        internal
        returns (uint128)
    {
        // Store the peg-out signature hash on-chain and initialize the signatures using txid
        bytes32 key = keccak256(abi.encodePacked(_streamId, _packetNumber, _slotId));
        pegoutTxids[key] = _pegoutTxid;

        // Get the committee key
        uint128 committeeId = streamManager.getCommitteeId(_streamId, _packetNumber);

        // Initialize the signatures for each member using txid
        signatureManager.initSignatures(_pegoutTxid, committeeId);

        return committeeId;
    }

    /// @inheritdoc IPegoutManager
    function triggerOperatorTake(bytes32 _pegoutTxid) external nonReentrant whenNotPaused {
        bytes32 acceptPeginTxid = pegoutToPeginTxid[_pegoutTxid];
        if (acceptPeginTxid == bytes32(0)) {
            revert PegoutTxidNotFound(_pegoutTxid);
        }

        PegoutTempInfo storage pegoutInfo = pegoutTempInfo[acceptPeginTxid];
        StreamPosition memory streamInfo = streamManager.getStreamPosition(acceptPeginTxid);
        bool advanceSlot = false;
        uint256 operatorTakeUpdatedAt = pegoutInfo.operatorTakeUpdatedAt;
        pegoutInfo.operatorTakeUpdatedAt = block.timestamp;

        //slither-disable-next-line unused-return
        (SignatureData[] memory signatureData, uint8 missingSignatures, uint8 missingNonces,) =
            signatureManager.getPartialSignatures(_pegoutTxid);

        if (streamInfo.pegStatus == PegStatus.USER_TAKE) {
            if (missingSignatures == 0) {
                revert UserTakeAlreadySigned(_pegoutTxid);
            }

            // slither-disable-next-line timestamp
            if (block.timestamp <= pegoutInfo.createdAt + userTakeTimeout) {
                revert UserTakeTimeoutNotExpired(pegoutInfo.createdAt, pegoutInfo.createdAt + userTakeTimeout);
            }

            streamManager.setPegStatus(acceptPeginTxid, PegStatus.OP_SELECTED);
            advanceSlot = true;
        } else if (streamInfo.pegStatus == PegStatus.OP_SELECTED) {
            // slither-disable-next-line timestamp
            if (block.timestamp <= operatorTakeUpdatedAt + operatorTakeTimeout) {
                revert OperatorTakeTimeoutNotExpired(operatorTakeUpdatedAt, operatorTakeUpdatedAt + operatorTakeTimeout);
            }
            // TODO: Handle other PegStatus like ADVANCED and KICKOFF.
            // TODO: would this go here? or in challengeManager now that we have it?
        } else {
            revert InvalidPegStatus(streamInfo.pegStatus);
        }

        // slither-disable-next-line reentrancy-no-eth reentrancy-benign
        (address takeOperatorAddress, bytes32 operatorDisputePubKey) =
            committeeRegistry.getOperatorDisputeData(pegoutInfo.committeeId, signatureData, missingNonces);

        // Update state variables after external calls
        pegoutInfo.takeOperatorAddress = takeOperatorAddress;
        pegoutInfo.operatorDisputePubKey = operatorDisputePubKey;

        // Fetch updated streamInfo after potential status change
        StreamPosition memory updatedStreamInfo = streamManager.getStreamPosition(acceptPeginTxid);

        // slither-disable-next-line reentrancy-events
        emit OperatorTakeTriggered(
            _pegoutTxid, pegoutInfo, updatedStreamInfo, block.timestamp, block.timestamp + operatorTakeTimeout
        );

        if (advanceSlot) {
            streamManager.advanceSlot(
                updatedStreamInfo.streamId, updatedStreamInfo.packetNumber, updatedStreamInfo.slotId
            );
        }
    }

    /// @inheritdoc IPegoutManager
    function registerAdvanceFunds(bytes32 acceptPeginTxid, BtcTxSPVProof memory _advanceFunds)
        external
        nonReentrant
        whenNotPaused
    {
        StreamPosition memory streamInfo = _validatePegStatus(acceptPeginTxid, PegStatus.OP_SELECTED);

        PegoutTempInfo storage pegoutInfo = _validateOperatorTakeAddress(acceptPeginTxid);

        (bytes32 txid, int256 blockNumber) = _verifyAdvanceFundsTx(_advanceFunds, pegoutInfo, streamInfo.streamId);

        // update the peg status to ADVANCED
        streamManager.setPegStatus(acceptPeginTxid, PegStatus.ADVANCED);

        // Update advance funds block number
        pegoutInfo.advanceFundsBlockNumber = blockNumber;

        // slither-disable-next-line reentrancy-events
        emit AdvanceFundsRegistered(
            _advanceFunds.blockHash, txid, acceptPeginTxid, pegoutInfo.pegoutId, pegoutInfo.committeeId, streamInfo
        );
    }

    function _verifyAdvanceFundsTx(
        BtcTxSPVProof memory _advanceFunds,
        PegoutTempInfo memory _pegoutInfo,
        uint64 _streamId
    ) internal view returns (bytes32 txid, int256 blockNumber) {
        // Calculate the transaction id for verification
        txid = bitcoinManager.getBtcTxid(_advanceFunds.btcTx);

        // Get the stream to check confirmations
        Stream memory stream = streamManager.getStreamById(_streamId);

        // Verify the txid is part of the Merkle Root and has enough confirmations
        blockNumber = rbtcBridge.getTxBlockNumberAndVerifyConfirmations(
            stream.pegoutConfirmations,
            txid,
            _advanceFunds.blockHash,
            _advanceFunds.merkleBranchPath,
            _advanceFunds.merkleBranchHashes
        );

        uint64 userAmount = stream.denomination - (Constants.P2TR_FEE * 2 + Constants.SPEED_UP_AMOUNT);

        if (_advanceFunds.btcTx.outputs[Constants.ADVANCE_FUNDS_VOUT_USER].amount != userAmount) {
            revert WrongUserAmount(_advanceFunds.btcTx.outputs[Constants.ADVANCE_FUNDS_VOUT_USER].amount, userAmount);
        }

        // Validate that the first output pays to the operator's dispute key
        bitcoinManager.validatePegoutUserOutput(
            _advanceFunds.btcTx.outputs[Constants.ADVANCE_FUNDS_VOUT_USER], _pegoutInfo.userPubKey
        );

        // Validate that the second output contains the pegout ID
        bitcoinManager.validatePegoutIdOutput(
            _advanceFunds.btcTx.outputs[Constants.ADVANCE_FUNDS_VOUT_OP_RETURN], _pegoutInfo.pegoutId
        );
    }

    function _validateOperatorTakeAddress(bytes32 _acceptPeginTxid) internal view returns (PegoutTempInfo storage) {
        PegoutTempInfo storage pegoutInfo = pegoutTempInfo[_acceptPeginTxid];
        address sender = _msgSender();
        if (pegoutInfo.takeOperatorAddress != sender) {
            revert OperatorTakeAddressNotMatch(pegoutInfo.takeOperatorAddress, sender);
        }
        return pegoutInfo;
    }

    /// @inheritdoc IPegoutManager
    function registerReimbursementKickoff(bytes32 acceptPeginTxid, BtcTxSPVProof memory _kickoffSPV)
        external
        nonReentrant
        whenNotPaused
    {
        StreamPosition memory streamInfo = _validatePegStatus(acceptPeginTxid, PegStatus.ADVANCED);
        PegoutTempInfo storage pegoutInfo = _validateOperatorTakeAddress(acceptPeginTxid);

        if (_kickoffSPV.btcTx.inputs.length != Constants.KICKOFF_INPUT_COUNT) {
            revert InvalidKickoffInputCount(_kickoffSPV.btcTx.inputs.length, Constants.KICKOFF_INPUT_COUNT);
        }

        if (_kickoffSPV.btcTx.inputs[Constants.KICKOFF_VIN_SLOT_ID].vout != streamInfo.slotId) {
            revert InvalidSlotId(_kickoffSPV.btcTx.inputs[Constants.KICKOFF_VIN_SLOT_ID].vout, streamInfo.slotId);
        }

        // Calculate the transaction id for verification
        bytes32 txid = bitcoinManager.getBtcTxid(_kickoffSPV.btcTx);

        Stream memory stream = streamManager.getStreamById(streamInfo.streamId);

        // Verify the txid is part of the Merkle Root and has enough confirmations
        int256 blockNumber = rbtcBridge.getTxBlockNumberAndVerifyConfirmations(
            stream.pegoutConfirmations,
            txid,
            _kickoffSPV.blockHash,
            _kickoffSPV.merkleBranchPath,
            _kickoffSPV.merkleBranchHashes
        );

        if (blockNumber < pegoutInfo.advanceFundsBlockNumber) {
            revert ReimbursementKickoffBeforeAdvanceFunds(pegoutInfo.advanceFundsBlockNumber, blockNumber);
        }

        // Update the reimbursement kickoff txid
        pegoutInfo.reimbursementKickoffTxid = txid;

        // update the peg status to KICKOFF
        streamManager.setPegStatus(acceptPeginTxid, PegStatus.KICKOFF);

        emit ReimbursementKickoffRegistered(txid, acceptPeginTxid, pegoutInfo.committeeId, streamInfo);
    }

    /// @inheritdoc IPegoutManager
    function registerOperatorTake(BtcTxSPVProof memory _pegoutTxSPVProof) external nonReentrant whenNotPaused {
        // Get the accept peg-in tx id from the first input (this is what gets spent)
        bytes32 acceptPeginTxid = _pegoutTxSPVProof.btcTx.inputs[Constants.OPERATOR_TAKE_VIN_ACCEPT_PEGIN].txId;
        uint32 vout = _pegoutTxSPVProof.btcTx.inputs[Constants.OPERATOR_TAKE_VIN_ACCEPT_PEGIN].vout;

        StreamPosition memory streamInfo = _validatePegStatus(acceptPeginTxid, PegStatus.KICKOFF);

        // Validate that the vout is correct
        if (vout != Constants.ACCEPT_PEGIN_VOUT_TAPTREE) {
            revert IncorrectVout(vout, Constants.ACCEPT_PEGIN_VOUT_TAPTREE);
        }

        PegoutTempInfo storage pegoutInfo = _validateOperatorTakeAddress(acceptPeginTxid);

        if (
            pegoutInfo.reimbursementKickoffTxid
                != _pegoutTxSPVProof.btcTx.inputs[Constants.OPERATOR_TAKE_VIN_REIMBURSEMENT_KICKOFF].txId
        ) {
            revert ReimbursementKickoffTxidNotMatch(
                pegoutInfo.reimbursementKickoffTxid,
                _pegoutTxSPVProof.btcTx.inputs[Constants.OPERATOR_TAKE_VIN_REIMBURSEMENT_KICKOFF].txId
            );
        }

        // Validate that the first output pays to the operator's dispute key
        bitcoinManager.validatePegoutMemberOutput(
            _pegoutTxSPVProof.btcTx.outputs[Constants.OPERATOR_TAKE_VOUT_OPERATOR], pegoutInfo.operatorDisputePubKey
        );

        // Calculate the transaction id for verification
        bytes32 txid = bitcoinManager.getBtcTxid(_pegoutTxSPVProof.btcTx);

        OperatorTakeData memory opTakeData = _getOperatorTakeData(acceptPeginTxid, pegoutInfo.takeOperatorAddress);

        // Validate operator take txid matched the one deposited during accept pegin
        if (txid != opTakeData.takeTxid) {
            revert OperatorTakeTxidNotMatch(txid, opTakeData.takeTxid);
        }

        // Get the stream to check confirmations
        Stream memory stream = streamManager.getStreamById(streamInfo.streamId);

        // Verify the txid is part of the Merkle Root and has enough confirmations
        rbtcBridge.verifyTxConfirmations(
            stream.pegoutConfirmations,
            txid,
            _pegoutTxSPVProof.blockHash,
            _pegoutTxSPVProof.merkleBranchPath,
            _pegoutTxSPVProof.merkleBranchHashes
        );

        // slither-disable-next-line reentrancy-events
        emit PegoutRegistered(_pegoutTxSPVProof.blockHash, txid, acceptPeginTxid, pegoutInfo.committeeId, streamInfo);

        // update the peg status to COMPLETED
        streamManager.setPegStatus(acceptPeginTxid, PegStatus.COMPLETED);
        _completeSlot(streamInfo, acceptPeginTxid, txid);
    }

    /// @notice Deposits an operator won proof for a peg-out transaction
    /// @param _pegoutTxSPVProof The BTC SPV proof of the operator won transaction
    /// @dev Validates the SPV proof and marks the slot as paid when operator takes over
    /// @dev Only callable when the peg status is OPERATOR_TAKE
    /// @dev Emits PegoutRegistered event upon successful deposit
    /// @dev Only callable when contract is unpaused
    function registerOperatorWon(BtcTxSPVProof memory _pegoutTxSPVProof) external nonReentrant whenNotPaused {
        // Get the accept peg-in tx id from the first input (this is what gets spent)
        bytes32 acceptPeginTxid = _pegoutTxSPVProof.btcTx.inputs[Constants.OPERATOR_TAKE_VIN_ACCEPT_PEGIN].txId;
        uint32 vout = _pegoutTxSPVProof.btcTx.inputs[Constants.OPERATOR_TAKE_VIN_ACCEPT_PEGIN].vout;

        StreamPosition memory streamInfo = _validatePegStatus(acceptPeginTxid, PegStatus.REVEALED);

        // Validate that the vout is correct
        if (vout != Constants.ACCEPT_PEGIN_VOUT_TAPTREE) {
            revert IncorrectVout(vout, Constants.ACCEPT_PEGIN_VOUT_TAPTREE);
        }

        PegoutTempInfo storage pegoutInfo = _validateOperatorTakeAddress(acceptPeginTxid);

        ChallengeTempInfo memory challengeTempInfo =
            IChallengeManager(accessManager.challengeManager()).getChallengeTempInfo(acceptPeginTxid);

        if (
            challengeTempInfo.revealTxid
                != _pegoutTxSPVProof.btcTx.inputs[Constants.OPERATOR_WON_VIN_INPUT_REVEALED].txId
        ) {
            revert InputRevealedTxidNotMatch(
                challengeTempInfo.revealTxid,
                _pegoutTxSPVProof.btcTx.inputs[Constants.OPERATOR_WON_VIN_INPUT_REVEALED].txId
            );
        }

        // Validate that the first output pays to the operator's dispute key
        bitcoinManager.validatePegoutMemberOutput(
            _pegoutTxSPVProof.btcTx.outputs[Constants.OPERATOR_WON_VOUT_OPERATOR], pegoutInfo.operatorDisputePubKey
        );

        // Calculate the transaction id for verification
        bytes32 txid = bitcoinManager.getBtcTxid(_pegoutTxSPVProof.btcTx);

        (OperatorTakeData memory opTakeData) = _getOperatorTakeData(acceptPeginTxid, pegoutInfo.takeOperatorAddress);

        // Validate operator take txid matched the one deposited during accept pegin
        if (txid != opTakeData.wonTxid) {
            revert OperatorWonTxidNotMatch(txid, opTakeData.wonTxid);
        }

        // Get the stream to check confirmations
        Stream memory stream = streamManager.getStreamById(streamInfo.streamId);

        // Verify the txid is part of the Merkle Root and has enough confirmations
        rbtcBridge.verifyTxConfirmations(
            stream.pegoutConfirmations,
            txid,
            _pegoutTxSPVProof.blockHash,
            _pegoutTxSPVProof.merkleBranchPath,
            _pegoutTxSPVProof.merkleBranchHashes
        );

        // slither-disable-next-line reentrancy-events
        emit PegoutRegistered(_pegoutTxSPVProof.blockHash, txid, acceptPeginTxid, pegoutInfo.committeeId, streamInfo);

        // update the peg status to COMPLETED
        streamManager.setPegStatus(acceptPeginTxid, PegStatus.COMPLETED);
        _completeSlot(streamInfo, acceptPeginTxid, txid);
    }

    function _completeSlot(StreamPosition memory _streamInfo, bytes32 _acceptPeginTxid, bytes32 _txid) internal {
        bool packetClosed = streamManager.completeSlot(_streamInfo, _acceptPeginTxid, _txid);
        if (packetClosed) {
            committeeRegistry.releaseCommittee(_streamInfo.streamId, _streamInfo.packetNumber);
        }
    }

    function _getOperatorTakeData(bytes32 _acceptPeginTxid, address _opAddress)
        internal
        view
        returns (OperatorTakeData memory)
    {
        OperatorTakeData[] memory opTakeDataArray = signatureManager.getOperatorTakeData(_acceptPeginTxid);
        for (uint256 i = 0; i < opTakeDataArray.length; i++) {
            if (opTakeDataArray[i].memberAddress == _opAddress) {
                return opTakeDataArray[i];
            }
        }

        revert OperatorTakeDataNotFound(_acceptPeginTxid, _opAddress);
    }

    /// @inheritdoc IPegoutManager
    function setUserTakeTimeout(uint256 _timeout) external onlyOwner {
        if (_timeout == 0) {
            revert InvalidTimeout(_timeout);
        }
        userTakeTimeout = _timeout;
        emit UserTakeTimeoutUpdated(userTakeTimeout);
    }

    /// @inheritdoc IPegoutManager
    function setOperatorTakeTimeout(uint256 _timeout) external onlyOwner {
        if (_timeout == 0) {
            revert InvalidTimeout(_timeout);
        }
        operatorTakeTimeout = _timeout;
        emit OperatorTakeTimeoutUpdated(operatorTakeTimeout);
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
