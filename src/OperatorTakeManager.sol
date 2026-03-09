// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {IOperatorTakeManager, TakeTimeout} from "./interfaces/IOperatorTakeManager.sol";
import {ChallengeInfo, IChallengeManager} from "./interfaces/IChallengeManager.sol";
import {OperatorTakeInfo} from "./interfaces/IOperatorTakeManager.sol";
import {IPegoutManager, PegoutStartInfo} from "./interfaces/IPegoutManager.sol";
import {PegManagerBase} from "./PegManagerBase.sol";
import {ICommitteeRegistry} from "./interfaces/ICommitteeRegistry.sol";
import {IBitcoinManager, BtcTxIn} from "./interfaces/IBitcoinManager.sol";
import {IRbtcBridge} from "./interfaces/IRbtcBridge.sol";
import {BtcTxSPVProof, StreamPosition} from "./interfaces/IPegCommonTypes.sol";
import {Constants} from "./libraries/Constants.sol";
import {IStreamManager, PegStatus, Stream, StreamDenomination} from "./interfaces/IStreamManager.sol";
import {OperatorTakeData, ISignatureManager, SignatureData} from "./interfaces/ISignatureManager.sol";

/// @title OperatorTakeManager
/// @notice Manages operator take flow: trigger, advance funds, reimbursement kickoff, operator take, operator won
contract OperatorTakeManager is IOperatorTakeManager, PegManagerBase {
    /// @notice The PegoutManager contract
    IPegoutManager public pegoutManager;

    /// @notice The ChallengeManager contract
    IChallengeManager public challengeManager;

    /// @notice Per-stream timeout settings indexed by stream ID
    mapping(uint256 => TakeTimeout) public takeTimeouts;

    /// @notice The pegout ID sequence number incremented for each new triggerOperatorTake
    uint256 public sequenceNumber;

    /// @notice Mapping that connects the blockNumber where the cancel user take tx was mined with its corresponding acceptPeginTxid
    mapping(bytes32 acceptPeginTxid => int256 blockNumber) internal cancelUserTakeTxBlockNumber;

    mapping(bytes32 acceptPeginTxid => OperatorTakeInfo info) internal operatorTakeInfo;

    /// @notice Initializes the OperatorTakeManager contract
    /// @param _initialOwner The initial owner of the contract
    /// @param _accessManager The access manager contract address
    /// @param _committeeRegistry The committee registry contract address
    /// @param _bitcoinManager The Bitcoin manager contract address
    /// @param _rbtcBridge The rbtc bridge contract address for verifying Bitcoin transaction confirmations
    /// @param _pegoutManager The pegout manager contract address
    /// @param _streamManager The stream manager contract address
    /// @param _signatureManager The signature manager contract address
    /// @param _takeTimeouts Per-stream timeout settings indexed by stream ID
    function initialize(
        address _initialOwner,
        address _accessManager,
        ICommitteeRegistry _committeeRegistry,
        IBitcoinManager _bitcoinManager,
        IRbtcBridge _rbtcBridge,
        IPegoutManager _pegoutManager,
        IStreamManager _streamManager,
        ISignatureManager _signatureManager,
        TakeTimeout[] memory _takeTimeouts
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
        if (address(_pegoutManager) == address(0)) {
            revert InvalidZeroAddress();
        }
        pegoutManager = _pegoutManager;
        _setTakeTimeouts(_takeTimeouts);
    }

    function _setTakeTimeouts(TakeTimeout[] memory _settings) internal {
        uint64 numStreams = uint64(StreamDenomination.LENGTH);
        if (_settings.length != numStreams) {
            revert InvalidTimeoutsLength();
        }
        for (uint64 i = 0; i < numStreams; i++) {
            _setTakeTimeout(i, _settings[i]);
        }
    }

    /// @inheritdoc IOperatorTakeManager
    function setTakeTimeout(uint64 _streamId, TakeTimeout memory _timeout) external onlyOwner {
        _setTakeTimeout(_streamId, _timeout);
        emit TakeTimeoutUpdated(_streamId, _timeout);
    }

    function _setTakeTimeout(uint64 _streamId, TakeTimeout memory _timeout) internal {
        if (_timeout.userTake == 0) {
            revert InvalidTimeout(_timeout.userTake);
        }
        if (_timeout.operatorTake == 0) {
            revert InvalidTimeout(_timeout.operatorTake);
        }
        takeTimeouts[_streamId] = _timeout;
    }

    /// @inheritdoc IOperatorTakeManager
    function setChallengeManager(address _challengeManager) external onlyOwner {
        if (address(challengeManager) != address(0)) {
            revert AlreadySet();
        }
        if (_challengeManager == address(0)) {
            revert InvalidZeroAddress();
        }
        challengeManager = IChallengeManager(_challengeManager);
    }

    /// @inheritdoc IOperatorTakeManager
    function getOperatorTakeInfo(bytes32 _acceptPeginTxid) external view returns (OperatorTakeInfo memory) {
        return operatorTakeInfo[_acceptPeginTxid];
    }

    /// @inheritdoc IOperatorTakeManager
    function registerCancelUserTake(BtcTxSPVProof calldata _cancelUserTakeSPVProof)
        external
        nonReentrant
        whenNotPaused
    {
        if (_cancelUserTakeSPVProof.btcTx.inputs.length != Constants.CANCEL_USER_TAKE_INPUT_COUNT) {
            revert IPegoutManager.IncorrectInputsNumber(
                _cancelUserTakeSPVProof.btcTx.inputs.length, Constants.CANCEL_USER_TAKE_INPUT_COUNT
            );
        }
        if (_cancelUserTakeSPVProof.btcTx.outputs.length != Constants.CANCEL_USER_TAKE_OUTPUT_COUNT) {
            revert IPegoutManager.IncorrectOutputsNumber(
                _cancelUserTakeSPVProof.btcTx.outputs.length, Constants.CANCEL_USER_TAKE_OUTPUT_COUNT
            );
        }

        bytes32 acceptPeginTxid = _cancelUserTakeSPVProof.btcTx.inputs[Constants.CANCEL_USER_TAKE_VIN_ACCEPT_PEGIN].txId;

        if (cancelUserTakeTxBlockNumber[acceptPeginTxid] > 0) {
            revert CancelUserTakeAlreadyRegistered(acceptPeginTxid);
        }

        // slither-disable-next-line unused-return
        (,, uint8 pegoutConfirmations) = streamManager.validatePegoutStatus(acceptPeginTxid, PegStatus.OP_SELECTED);

        // Validate that the vout is correct
        uint32 vout = _cancelUserTakeSPVProof.btcTx.inputs[Constants.CANCEL_USER_TAKE_VIN_ACCEPT_PEGIN].vout;
        if (vout != Constants.ACCEPT_PEGIN_VOUT_ENABLER) {
            revert IPegoutManager.IncorrectVout(vout, Constants.ACCEPT_PEGIN_VOUT_ENABLER);
        }

        // Calculate the transaction id for verification
        bytes32 txid = bitcoinManager.getBtcTxid(_cancelUserTakeSPVProof.btcTx);

        // Verify the txid is part of the Merkle Root and has enough confirmations
        int256 blockNumber = rbtcBridge.getTxBlockNumberAndVerifyConfirmations(
            pegoutConfirmations,
            txid,
            _cancelUserTakeSPVProof.blockHash,
            _cancelUserTakeSPVProof.merkleBranchPath,
            _cancelUserTakeSPVProof.merkleBranchHashes
        );

        // TODO when having slashing mechanism,
        // if the operator that mined the cancel user take tx in bitcoin
        // did it before the user take flow was expired,
        // we should penalize him

        cancelUserTakeTxBlockNumber[acceptPeginTxid] = blockNumber;
        emit CancelUserTakeRegistered(acceptPeginTxid);
    }

    /// @inheritdoc IOperatorTakeManager
    function getCancelUserTakeTxBlockNumber(bytes32 _acceptPeginTxid) external view returns (int256 blockNumber) {
        return cancelUserTakeTxBlockNumber[_acceptPeginTxid];
    }

    /// @inheritdoc IOperatorTakeManager
    function triggerOperatorTake(bytes32 _acceptPeginTxid) external nonReentrant whenNotPaused {
        PegoutStartInfo memory pegoutInfo = pegoutManager.getPegoutStartInfo(_acceptPeginTxid);
        StreamPosition memory streamInfo = streamManager.getStreamPosition(_acceptPeginTxid);

        (SignatureData[] memory signatureData, uint8 missingSignatures, uint8 missingNonces, uint128 committeeId) =
            signatureManager.getPartialSignatures(pegoutInfo.pegoutTxid);

        OperatorTakeInfo storage opInfo = operatorTakeInfo[_acceptPeginTxid];
        unchecked {
            sequenceNumber++;
        }

        if (streamInfo.pegStatus == PegStatus.USER_TAKE) {
            _handleUserTake(_acceptPeginTxid, pegoutInfo.createdAt, missingSignatures, streamInfo.streamId);
        } else if (
            streamInfo.pegStatus == PegStatus.OP_SELECTED || streamInfo.pegStatus == PegStatus.ADVANCED
                || streamInfo.pegStatus == PegStatus.KICKOFF
        ) {
            _verifyOperatorTakeTimeoutExpired(opInfo.operatorTakeUpdatedAt, streamInfo.streamId);
        } else if (streamInfo.pegStatus == PegStatus.CHALLENGE || streamInfo.pegStatus == PegStatus.REVEALED) {
            // Only the challenge manager can trigger operator take in these states
            // we use msg.sender instead of _msgSender() as this case should not be relayed
            accessManager.revertIfNotChallengeManager(msg.sender);
        } else {
            revert InvalidPegStatus(streamInfo.pegStatus);
        }

        (address operatorTakeAddress, bytes32 operatorDisputePubKey, bytes32 operatorTakePubKey) =
            committeeRegistry.selectTakeOperator(committeeId, signatureData, missingNonces);
        // delete the previous operator take info if exists then update with the new selected operator
        delete operatorTakeInfo[_acceptPeginTxid];
        _updateOperatorTakeInfo(opInfo, streamInfo, operatorTakeAddress, operatorDisputePubKey, operatorTakePubKey);

        // save on a contract call if already set
        if (streamInfo.pegStatus != PegStatus.OP_SELECTED) {
            streamManager.setPegStatus(_acceptPeginTxid, PegStatus.OP_SELECTED);
        }

        streamInfo.pegStatus = PegStatus.OP_SELECTED;
        // slither-disable-next-line reentrancy-events
        emit OperatorTakeTriggered(
            pegoutInfo.pegoutTxid,
            opInfo,
            streamInfo,
            block.timestamp,
            block.timestamp + takeTimeouts[streamInfo.streamId].operatorTake
        );
    }

    function _handleUserTake(
        bytes32 _acceptPeginTxid,
        uint256 _pegoutCreatedAt,
        uint8 _missingSignatures,
        uint64 _streamId
    ) internal {
        if (_missingSignatures == 0) {
            revert UserTakeAlreadySigned(_acceptPeginTxid);
        }
        // slither-disable-next-line timestamp
        if (block.timestamp <= _pegoutCreatedAt + takeTimeouts[_streamId].userTake) {
            revert UserTakeTimeoutNotExpired(_pegoutCreatedAt, _pegoutCreatedAt + takeTimeouts[_streamId].userTake);
        }

        // slither-disable-next-line reentrancy-no-eth reentrancy-benign
        streamManager.advanceSlot(_acceptPeginTxid);
    }

    function _verifyOperatorTakeTimeoutExpired(uint256 _operatorTakeUpdatedAt, uint64 _streamId) internal view {
        // slither-disable-next-line timestamp
        if (block.timestamp <= _operatorTakeUpdatedAt + takeTimeouts[_streamId].operatorTake) {
            revert OperatorTakeTimeoutNotExpired(
                _operatorTakeUpdatedAt, _operatorTakeUpdatedAt + takeTimeouts[_streamId].operatorTake
            );
        }
    }

    function _updateOperatorTakeInfo(
        OperatorTakeInfo storage _opInfo,
        StreamPosition memory _streamInfo,
        address _operatorTakeAddress,
        bytes32 _operatorDisputePubKey,
        bytes32 _operatorTakePubKey
    ) internal {
        _opInfo.operatorTakeUpdatedAt = block.timestamp;
        _opInfo.operatorTakeAddress = _operatorTakeAddress;
        _opInfo.operatorTakePubKey = _operatorTakePubKey;
        _opInfo.operatorDisputePubKey = _operatorDisputePubKey;
        _opInfo.pegoutId = _generatePegoutId(_streamInfo, _operatorTakePubKey, sequenceNumber);
    }

    function _generatePegoutId(StreamPosition memory _streamInfo, bytes32 _operatorTakePubKey, uint256 _sequenceNumber)
        internal
        view
        returns (bytes32)
    {
        bytes32 pegoutId = keccak256(
            abi.encodePacked(
                Constants.PEGOUT_ID_VERSION,
                _sequenceNumber,
                _streamInfo.streamId,
                _streamInfo.packetNumber,
                _streamInfo.slotId,
                _operatorTakePubKey,
                rbtcBridge.getBestBlockHash() // used as randomness for the pegout ID
            )
        );
        return pegoutId;
    }

    /// @inheritdoc IOperatorTakeManager
    function registerAdvanceFunds(bytes32 _acceptPeginTxid, BtcTxSPVProof calldata _advanceFunds)
        external
        nonReentrant
        whenNotPaused
    {
        // slither-disable-next-line unused-return
        (StreamPosition memory streamInfo, uint128 committeeId,) =
            streamManager.validatePegoutStatus(_acceptPeginTxid, PegStatus.OP_SELECTED);

        OperatorTakeInfo storage opInfo = _validateOperatorTakeCaller(_acceptPeginTxid);
        PegoutStartInfo memory pegoutInfo = pegoutManager.getPegoutStartInfo(_acceptPeginTxid);

        (bytes32 txid, int256 blockNumber) =
            _verifyAdvanceFundsTx(_advanceFunds, pegoutInfo.userPubKey, opInfo.pegoutId, streamInfo.streamId);

        if (cancelUserTakeTxBlockNumber[_acceptPeginTxid] < blockNumber) {
            revert AdvanceFundsBeforeCancelUserTake(_acceptPeginTxid);
        }

        opInfo.operatorTakeUpdatedAt = block.timestamp;
        opInfo.advanceFundsBlockNumber = blockNumber;

        // slither-disable-next-line reentrancy-events
        emit AdvanceFundsRegistered(
            _advanceFunds.blockHash,
            txid,
            _acceptPeginTxid,
            opInfo.pegoutId,
            committeeId,
            streamInfo,
            opInfo.operatorTakePubKey
        );

        // update the peg status to ADVANCED
        streamManager.setPegStatus(_acceptPeginTxid, PegStatus.ADVANCED);
    }

    function _verifyAdvanceFundsTx(
        BtcTxSPVProof calldata _advanceFunds,
        bytes memory _userPubKey,
        bytes32 _pegoutId,
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

        if (_advanceFunds.btcTx.outputs[Constants.ADVANCE_FUNDS_VOUT_USER].amount < userAmount) {
            revert WrongUserAmount(_advanceFunds.btcTx.outputs[Constants.ADVANCE_FUNDS_VOUT_USER].amount, userAmount);
        }

        bitcoinManager.validatePegoutUserOutput(
            _advanceFunds.btcTx.outputs[Constants.ADVANCE_FUNDS_VOUT_USER], _userPubKey
        );

        bitcoinManager.validatePegoutIdOutput(
            _advanceFunds.btcTx.outputs[Constants.ADVANCE_FUNDS_VOUT_OP_RETURN], _pegoutId
        );
    }

    /// @inheritdoc IOperatorTakeManager
    function registerReimbursementKickoff(bytes32 _acceptPeginTxid, BtcTxSPVProof calldata _kickoffSPV)
        external
        nonReentrant
        whenNotPaused
    {
        (StreamPosition memory streamInfo, uint128 committeeId, uint8 pegoutConfirmations) =
            streamManager.validatePegoutStatus(_acceptPeginTxid, PegStatus.ADVANCED);

        OperatorTakeInfo storage opInfo = _validateOperatorTakeCaller(_acceptPeginTxid);

        if (_kickoffSPV.btcTx.inputs.length != Constants.KICKOFF_INPUT_COUNT) {
            revert InvalidKickoffInputCount(_kickoffSPV.btcTx.inputs.length, Constants.KICKOFF_INPUT_COUNT);
        }

        if (_kickoffSPV.btcTx.inputs[Constants.KICKOFF_VIN_SLOT_ID].vout != streamInfo.slotId) {
            revert InvalidSlotId(_kickoffSPV.btcTx.inputs[Constants.KICKOFF_VIN_SLOT_ID].vout, streamInfo.slotId);
        }

        // Calculate the transaction id for verification
        bytes32 txid = bitcoinManager.getBtcTxid(_kickoffSPV.btcTx);

        // Verify the txid is part of the Merkle Root and has enough confirmations
        int256 blockNumber = rbtcBridge.getTxBlockNumberAndVerifyConfirmations(
            pegoutConfirmations,
            txid,
            _kickoffSPV.blockHash,
            _kickoffSPV.merkleBranchPath,
            _kickoffSPV.merkleBranchHashes
        );

        if (blockNumber < opInfo.advanceFundsBlockNumber) {
            revert ReimbursementKickoffBeforeAdvanceFunds(opInfo.advanceFundsBlockNumber, blockNumber);
        }

        opInfo.operatorTakeUpdatedAt = block.timestamp;
        opInfo.reimbursementKickoffTxid = txid;

        emit ReimbursementKickoffRegistered(
            txid, _acceptPeginTxid, opInfo.pegoutId, committeeId, streamInfo, opInfo.operatorTakePubKey
        );

        streamManager.setPegStatus(_acceptPeginTxid, PegStatus.KICKOFF);
        rbtcBridge.setBaseEvent(abi.encodePacked(opInfo.pegoutId));
    }

    /// @inheritdoc IOperatorTakeManager
    function registerOperatorTake(BtcTxSPVProof calldata _pegoutTxSPVProof) external nonReentrant whenNotPaused {
        (
            bytes32 acceptPeginTxid,
            StreamPosition memory streamInfo,
            uint128 committeeId,
            uint8 pegoutConfirmations,
            OperatorTakeInfo storage opInfo
        ) = _parseOperatorPegoutInputs(_pegoutTxSPVProof.btcTx.inputs, PegStatus.KICKOFF);

        if (
            opInfo.reimbursementKickoffTxid
                != _pegoutTxSPVProof.btcTx.inputs[Constants.OPERATOR_TAKE_VIN_REIMBURSEMENT_KICKOFF].txId
        ) {
            revert ReimbursementKickoffTxidNotMatch(
                opInfo.reimbursementKickoffTxid,
                _pegoutTxSPVProof.btcTx.inputs[Constants.OPERATOR_TAKE_VIN_REIMBURSEMENT_KICKOFF].txId
            );
        }

        bitcoinManager.validatePegoutMemberOutput(
            _pegoutTxSPVProof.btcTx.outputs[Constants.OPERATOR_TAKE_VOUT_OPERATOR], opInfo.operatorDisputePubKey
        );

        bytes32 txid = bitcoinManager.getBtcTxid(_pegoutTxSPVProof.btcTx);

        OperatorTakeData memory opTakeData = _getOperatorTakeData(acceptPeginTxid, opInfo.operatorTakeAddress);

        // Validate operator take txid matched the one deposited during accept pegin
        if (txid != opTakeData.takeTxid) {
            revert OperatorTakeTxidNotMatch(txid, opTakeData.takeTxid);
        }

        _verifyConfirmationsEmitAndComplete(
            streamInfo,
            acceptPeginTxid,
            txid,
            _pegoutTxSPVProof.blockHash,
            _pegoutTxSPVProof.merkleBranchPath,
            _pegoutTxSPVProof.merkleBranchHashes,
            committeeId,
            pegoutConfirmations
        );
    }

    /// @inheritdoc IOperatorTakeManager
    function registerOperatorWon(BtcTxSPVProof calldata _pegoutTxSPVProof) external nonReentrant whenNotPaused {
        (
            bytes32 acceptPeginTxid,
            StreamPosition memory streamInfo,
            uint128 committeeId,
            uint8 pegoutConfirmations,
            OperatorTakeInfo storage opInfo
        ) = _parseOperatorPegoutInputs(_pegoutTxSPVProof.btcTx.inputs, PegStatus.REVEALED);

        ChallengeInfo memory challengeInfo = challengeManager.getChallengeInfo(acceptPeginTxid);

        if (challengeInfo.revealTxid != _pegoutTxSPVProof.btcTx.inputs[Constants.OPERATOR_WON_VIN_INPUT_REVEALED].txId)
        {
            revert InputRevealedTxidNotMatch(
                challengeInfo.revealTxid, _pegoutTxSPVProof.btcTx.inputs[Constants.OPERATOR_WON_VIN_INPUT_REVEALED].txId
            );
        }

        bitcoinManager.validatePegoutMemberOutput(
            _pegoutTxSPVProof.btcTx.outputs[Constants.OPERATOR_WON_VOUT_OPERATOR], opInfo.operatorDisputePubKey
        );

        bytes32 txid = bitcoinManager.getBtcTxid(_pegoutTxSPVProof.btcTx);

        OperatorTakeData memory opTakeData = _getOperatorTakeData(acceptPeginTxid, opInfo.operatorTakeAddress);

        // Validate operator take txid matched the one deposited during accept pegin
        if (txid != opTakeData.wonTxid) {
            revert OperatorWonTxidNotMatch(txid, opTakeData.wonTxid);
        }

        _verifyConfirmationsEmitAndComplete(
            streamInfo,
            acceptPeginTxid,
            txid,
            _pegoutTxSPVProof.blockHash,
            _pegoutTxSPVProof.merkleBranchPath,
            _pegoutTxSPVProof.merkleBranchHashes,
            committeeId,
            pegoutConfirmations
        );
    }

    /// @inheritdoc IOperatorTakeManager
    function skipOperatorWon(bytes32 _acceptPeginTxid) external nonReentrant whenNotPaused {
        // slither-disable-next-line unused-return
        (StreamPosition memory streamInfo, uint128 committeeId,) =
            streamManager.validatePegoutStatus(_acceptPeginTxid, PegStatus.REVEALED);

        committeeRegistry.validateMemberInCommittee(committeeId, _msgSender());

        ChallengeInfo memory challengeInfo = challengeManager.getChallengeInfo(_acceptPeginTxid);

        Stream memory stream = streamManager.getStreamById(streamInfo.streamId);
        uint256 skipThreshold = uint256(stream.timelockSettings.opWonTimelock) + 2 * uint256(stream.pegoutConfirmations);

        int256 currentBtcHeight = rbtcBridge.bridge().getBtcBlockchainBestChainHeight();
        if (currentBtcHeight < challengeInfo.revealBtcBlockNumber + int256(skipThreshold)) {
            revert OperatorWonTimeoutNotExpired(challengeInfo.revealBtcBlockNumber, currentBtcHeight, skipThreshold);
        }

        emit OperatorWonSkipped(_acceptPeginTxid, committeeId, streamInfo);
        _completeSlot(streamInfo, _acceptPeginTxid, bytes32(0));
    }

    function _verifyConfirmationsEmitAndComplete(
        StreamPosition memory _streamInfo,
        bytes32 _acceptPeginTxid,
        bytes32 _txid,
        bytes32 _blockHash,
        uint256 _merkleBranchPath,
        bytes32[] memory _merkleBranchHashes,
        uint128 _committeeId,
        uint8 _pegoutConfirmations
    ) internal {
        _verifyPegoutConfirmations(_pegoutConfirmations, _txid, _blockHash, _merkleBranchPath, _merkleBranchHashes);
        // slither-disable-next-line reentrancy-events
        emit IPegoutManager.PegoutRegistered(_blockHash, _txid, _acceptPeginTxid, _committeeId, _streamInfo);
        _completeSlot(_streamInfo, _acceptPeginTxid, _txid);
    }

    function _verifyPegoutConfirmations(
        uint8 _pegoutConfirmations,
        bytes32 _txid,
        bytes32 _blockHash,
        uint256 _merkleBranchPath,
        bytes32[] memory _merkleBranchHashes
    ) internal view {
        rbtcBridge.verifyTxConfirmations(
            _pegoutConfirmations, _txid, _blockHash, _merkleBranchPath, _merkleBranchHashes
        );
    }

    function _parseOperatorPegoutInputs(BtcTxIn[] calldata _inputs, PegStatus _expectedStatus)
        internal
        view
        returns (
            bytes32 acceptPeginTxid,
            StreamPosition memory streamInfo,
            uint128 committeeId,
            uint8 pegoutConfirmations,
            OperatorTakeInfo storage opInfo
        )
    {
        acceptPeginTxid = _inputs[Constants.OPERATOR_TAKE_VIN_ACCEPT_PEGIN].txId;
        uint32 vout = _inputs[Constants.OPERATOR_TAKE_VIN_ACCEPT_PEGIN].vout;

        if (vout != Constants.ACCEPT_PEGIN_VOUT_TAPTREE) {
            revert IPegoutManager.IncorrectVout(vout, Constants.ACCEPT_PEGIN_VOUT_TAPTREE);
        }

        (streamInfo, committeeId, pegoutConfirmations) =
            streamManager.validatePegoutStatus(acceptPeginTxid, _expectedStatus);
        opInfo = _validateOperatorTakeCaller(acceptPeginTxid);
    }

    function _validateOperatorTakeCaller(bytes32 _acceptPeginTxid)
        internal
        view
        returns (OperatorTakeInfo storage opInfo)
    {
        opInfo = operatorTakeInfo[_acceptPeginTxid];
        address sender = _msgSender();
        if (opInfo.operatorTakeAddress != sender) {
            revert OperatorTakeAddressNotMatch(opInfo.operatorTakeAddress, sender);
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
}
