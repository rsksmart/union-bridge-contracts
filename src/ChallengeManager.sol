// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {ChallengeInfo, IChallengeManager} from "./interfaces/IChallengeManager.sol";
import {PegBase} from "./PegBase.sol";
import {BtcTxSPVProof, StreamPosition} from "./interfaces/IPegCommonTypes.sol";
import {Constants} from "./libraries/Constants.sol";
import {IStreamManager, PegStatus} from "./interfaces/IStreamManager.sol";
import {ICommitteeRegistry} from "./interfaces/ICommitteeRegistry.sol";
import {IBitcoinManager} from "./interfaces/IBitcoinManager.sol";
import {IOperatorTakeManager} from "./interfaces/IOperatorTakeManager.sol";
import {IRbtcBridge} from "./interfaces/IRbtcBridge.sol";

/// @title ChallengeManager
/// @notice Manages challenge operations
contract ChallengeManager is IChallengeManager, PegBase {
    /// @notice The PegoutManager contract
    IOperatorTakeManager public operatorTakeManager;

    /// @notice Information stored during challenge processing
    /// @dev Contains data needed for challenge transaction validation
    mapping(bytes32 acceptPeginTxid => ChallengeInfo info) internal challengeInfo;

    /// @inheritdoc IChallengeManager
    function getChallengeInfo(bytes32 _acceptPeginTxid) external view returns (ChallengeInfo memory) {
        return _getChallengeInfo(_acceptPeginTxid);
    }

    /// @notice Initializes the ChallengeManager contract
    /// @param _initialOwner The initial owner of the contract
    /// @param _accessManager The access manager contract address
    /// @param _committeeRegistry The committee registry contract address
    /// @param _bitcoinManager The Bitcoin manager contract address
    /// @param _rbtcBridge The rbtc bridge contract address for verifying Bitcoin transaction confirmations
    /// @param _streamManager The stream manager contract address
    function initialize(
        address _initialOwner,
        address _accessManager,
        ICommitteeRegistry _committeeRegistry,
        IBitcoinManager _bitcoinManager,
        IRbtcBridge _rbtcBridge,
        IStreamManager _streamManager,
        IOperatorTakeManager _operatorTakeManager
    ) public initializer {
        __PegBase_init(_initialOwner, _accessManager, _committeeRegistry, _bitcoinManager, _rbtcBridge, _streamManager);
        if (address(_operatorTakeManager) == address(0)) {
            revert InvalidZeroAddress();
        }
        operatorTakeManager = _operatorTakeManager;
    }

    /// @inheritdoc IChallengeManager
    function registerChallenge(bytes32 _acceptPeginTxid, BtcTxSPVProof calldata _challenge)
        external
        nonReentrant
        whenNotPaused
    {
        (StreamPosition memory streamInfo, uint128 committeeId, uint8 pegoutConfirmations) =
            streamManager.validatePegStatus(_acceptPeginTxid, PegStatus.KICKOFF);
        committeeRegistry.validateMemberInCommittee(committeeId, _msgSender());

        if (_challenge.btcTx.inputs.length != Constants.CHALLENGE_INPUT_COUNT) {
            revert InvalidChallengeInputCount(_challenge.btcTx.inputs.length, Constants.CHALLENGE_INPUT_COUNT);
        }

        bytes32 kickoffTxid = _challenge.btcTx.inputs[Constants.CHALLENGE_VIN_REIMBURSEMENT_KICKOFF].txId;
        bytes32 expectedKickoffTxid = operatorTakeManager.getOperatorTakeInfo(_acceptPeginTxid).reimbursementKickoffTxid;
        if (expectedKickoffTxid != kickoffTxid) {
            revert ReimbursementKickoffTxidNotMatch(kickoffTxid, expectedKickoffTxid);
        }

        // Calculate the transaction id for verification
        bytes32 txid = bitcoinManager.getBtcTxid(_challenge.btcTx);

        // Verify the txid is part of the Merkle Root and has enough confirmations
        rbtcBridge.verifyTxConfirmations(
            pegoutConfirmations, txid, _challenge.blockHash, _challenge.merkleBranchPath, _challenge.merkleBranchHashes
        );

        challengeInfo[_acceptPeginTxid] = ChallengeInfo({challengeTxid: txid, revealTxid: bytes32(0)});

        emit ChallengeRegistered(txid, _acceptPeginTxid, committeeId, streamInfo);

        streamManager.setPegStatus(_acceptPeginTxid, PegStatus.CHALLENGE);
    }

    function _getChallengeInfo(bytes32 _acceptPeginTxid) internal view returns (ChallengeInfo storage) {
        ChallengeInfo storage info = challengeInfo[_acceptPeginTxid];
        if (info.challengeTxid == bytes32(0)) {
            revert NoChallengeRegistered(_acceptPeginTxid);
        }
        return info;
    }

    /// @inheritdoc IChallengeManager
    function registerInputNotRevealed(bytes32 _acceptPeginTxid, BtcTxSPVProof calldata _inputNotRevealed)
        external
        nonReentrant
        whenNotPaused
    {
        (StreamPosition memory streamInfo, uint128 committeeId, uint8 pegoutConfirmations) =
            streamManager.validatePegStatus(_acceptPeginTxid, PegStatus.CHALLENGE);
        committeeRegistry.validateMemberInCommittee(committeeId, _msgSender());

        if (_inputNotRevealed.btcTx.inputs.length != Constants.INPUT_NOT_REVEALED_INPUT_COUNT) {
            revert InvalidInputNotRevealedInputCount(
                _inputNotRevealed.btcTx.inputs.length, Constants.INPUT_NOT_REVEALED_INPUT_COUNT
            );
        }

        uint256 expectedOutputCount = committeeRegistry.getCommitteeMembersLength(committeeId);
        if (_inputNotRevealed.btcTx.outputs.length != expectedOutputCount) {
            revert InvalidInputNotRevealedOutputCount(_inputNotRevealed.btcTx.outputs.length, expectedOutputCount);
        }

        ChallengeInfo storage info = _getChallengeInfo(_acceptPeginTxid);

        bytes32 challengeTxid = _inputNotRevealed.btcTx.inputs[Constants.INPUT_NOT_REVEALED_VIN_CHALLENGE].txId;
        if (info.challengeTxid != challengeTxid) {
            revert ChallengeTxidNotMatch(challengeTxid, info.challengeTxid);
        }

        // Calculate the transaction id for verification
        bytes32 txid = bitcoinManager.getBtcTxid(_inputNotRevealed.btcTx);

        // Verify the txid is part of the Merkle Root and has enough confirmations
        rbtcBridge.verifyTxConfirmations(
            pegoutConfirmations,
            txid,
            _inputNotRevealed.blockHash,
            _inputNotRevealed.merkleBranchPath,
            _inputNotRevealed.merkleBranchHashes
        );

        // Clean up challenge info as no reveal will happen
        delete challengeInfo[_acceptPeginTxid];
        emit InputNotRevealedRegistered(txid, _acceptPeginTxid, committeeId, streamInfo);

        operatorTakeManager.triggerOperatorTake(_acceptPeginTxid);
    }

    /// @inheritdoc IChallengeManager
    function registerInputRevealed(bytes32 _acceptPeginTxid, BtcTxSPVProof memory _inputRevealed)
        external
        nonReentrant
        whenNotPaused
    {
        (StreamPosition memory streamInfo, uint128 committeeId, uint8 pegoutConfirmations) =
            streamManager.validatePegStatus(_acceptPeginTxid, PegStatus.CHALLENGE);
        committeeRegistry.validateMemberInCommittee(committeeId, _msgSender());

        if (_inputRevealed.btcTx.inputs.length != Constants.INPUT_REVEALED_INPUT_COUNT) {
            revert InvalidRevealedInputCount(_inputRevealed.btcTx.inputs.length, Constants.INPUT_REVEALED_INPUT_COUNT);
        }

        if (_inputRevealed.btcTx.outputs.length != Constants.INPUT_REVEALED_OUTPUT_COUNT) {
            revert InvalidRevealedOutputCount(
                _inputRevealed.btcTx.outputs.length, Constants.INPUT_REVEALED_OUTPUT_COUNT
            );
        }

        ChallengeInfo storage info = _getChallengeInfo(_acceptPeginTxid);
        bytes32 challengeTxid = _inputRevealed.btcTx.inputs[Constants.INPUT_REVEALED_VIN_CHALLENGE].txId;
        if (info.challengeTxid != challengeTxid) {
            revert ChallengeTxidNotMatch(challengeTxid, info.challengeTxid);
        }

        // Calculate the transaction id for verification
        bytes32 txid = bitcoinManager.getBtcTxid(_inputRevealed.btcTx);

        // Verify the txid is part of the Merkle Root and has enough confirmations
        rbtcBridge.verifyTxConfirmations(
            pegoutConfirmations,
            txid,
            _inputRevealed.blockHash,
            _inputRevealed.merkleBranchPath,
            _inputRevealed.merkleBranchHashes
        );

        info.revealTxid = txid;
        emit RevealRegistered(txid, _acceptPeginTxid, committeeId, streamInfo);

        streamManager.setPegStatus(_acceptPeginTxid, PegStatus.REVEALED);
    }

    /// @inheritdoc IChallengeManager
    function registerStopOperatorWon(bytes32 _acceptPeginTxid, BtcTxSPVProof calldata _stopOperatorWon)
        external
        nonReentrant
        whenNotPaused
    {
        (StreamPosition memory streamInfo, uint128 committeeId, uint8 pegoutConfirmations) =
            streamManager.validatePegStatus(_acceptPeginTxid, PegStatus.REVEALED);
        committeeRegistry.validateMemberInCommittee(committeeId, _msgSender());

        if (_stopOperatorWon.btcTx.inputs.length != Constants.STOP_OPERATOR_WON_INPUT_COUNT) {
            revert InvalidStopOperatorWonInputCount(
                _stopOperatorWon.btcTx.inputs.length, Constants.STOP_OPERATOR_WON_INPUT_COUNT
            );
        }

        ChallengeInfo storage info = _getChallengeInfo(_acceptPeginTxid);
        bytes32 input0Txid = _stopOperatorWon.btcTx.inputs[0].txId;
        bytes32 input1Txid = _stopOperatorWon.btcTx.inputs[1].txId;

        // Validate that input 0 is not the accept peg-in txid used in Operator Won.
        if (input0Txid == _acceptPeginTxid) {
            revert InvalidStopOperatorWonTxid(input0Txid);
        }

        if (info.revealTxid != input0Txid && info.revealTxid != input1Txid) {
            revert RevealTxidNotMatch(input0Txid, input1Txid, info.revealTxid);
        }

        // Calculate the transaction id for verification
        bytes32 txid = bitcoinManager.getBtcTxid(_stopOperatorWon.btcTx);

        // Verify the txid is part of the Merkle Root and has enough confirmations
        rbtcBridge.verifyTxConfirmations(
            pegoutConfirmations,
            txid,
            _stopOperatorWon.blockHash,
            _stopOperatorWon.merkleBranchPath,
            _stopOperatorWon.merkleBranchHashes
        );

        // Clean up challenge info
        delete challengeInfo[_acceptPeginTxid];
        emit StopOperatorWonRegistered(txid, _acceptPeginTxid, committeeId, streamInfo);

        // Retrigger operator take. Update peg status
        operatorTakeManager.triggerOperatorTake(_acceptPeginTxid);
    }
}
