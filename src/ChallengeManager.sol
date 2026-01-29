// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {ChallengeTempInfo, IChallengeManager} from "./interfaces/IChallengeManager.sol";
import {PegBase} from "./PegBase.sol";
import {BtcTxSPVProof, StreamPosition} from "./interfaces/IPegCommonTypes.sol";
import {Constants} from "./libraries/Constants.sol";
import {IPegoutManager, PegoutTempInfo} from "./interfaces/IPegoutManager.sol";
import {IStreamManager, PegStatus, Stream} from "./interfaces/IStreamManager.sol";
import {ICommitteeRegistry} from "./interfaces/ICommitteeRegistry.sol";
import {IBitcoinManager} from "./interfaces/IBitcoinManager.sol";
import {IRbtcBridge} from "./interfaces/IRbtcBridge.sol";

/// @title ChallengeManager
/// @notice Manages challenge operations
contract ChallengeManager is IChallengeManager, PegBase {
    /// @notice The PegoutManager contract
    IPegoutManager public pegoutManager;

    /// @notice Temporary information stored during challenge processing
    /// @dev Contains data needed for challenge transaction validation
    mapping(bytes32 acceptPeginTxid => ChallengeTempInfo tempInfo) internal challengeTempInfo;

    /// @inheritdoc IChallengeManager
    function getChallengeTempInfo(bytes32 _acceptPeginTxid) external view returns (ChallengeTempInfo memory) {
        return challengeTempInfo[_acceptPeginTxid];
    }

    /// @notice Initializes the ChallengeManager contract
    /// @param _initialOwner The initial owner of the contract
    /// @param _accessManager The access manager contract address
    /// @param _committeeRegistry The committee registry contract address
    /// @param _bitcoinManager The Bitcoin manager contract address
    /// @param _rbtcBridge The rbtc bridge contract address for verifying Bitcoin transaction confirmations
    /// @param _pegoutManager The pegout manager contract address
    /// @param _streamManager The stream manager contract address
    function initialize(
        address _initialOwner,
        address _accessManager,
        ICommitteeRegistry _committeeRegistry,
        IBitcoinManager _bitcoinManager,
        IRbtcBridge _rbtcBridge,
        IPegoutManager _pegoutManager,
        IStreamManager _streamManager
    ) public initializer {
        __PegBase_init(_initialOwner, _accessManager, _committeeRegistry, _bitcoinManager, _rbtcBridge, _streamManager);
        if (address(_pegoutManager) == address(0)) {
            revert InvalidZeroAddress();
        }
        pegoutManager = _pegoutManager;
    }

    /// @inheritdoc IChallengeManager
    function registerChallenge(bytes32 _acceptPeginTxid, BtcTxSPVProof calldata _challenge)
        external
        nonReentrant
        whenNotPaused
    {
        StreamPosition memory streamInfo = _validatePegStatus(_acceptPeginTxid, PegStatus.KICKOFF);

        if (_challenge.btcTx.inputs.length != Constants.CHALLENGE_INPUT_COUNT) {
            revert InvalidChallengeInputCount(_challenge.btcTx.inputs.length, Constants.CHALLENGE_INPUT_COUNT);
        }

        PegoutTempInfo memory pegoutInfo = pegoutManager.getPegoutTempInfo(_acceptPeginTxid);
        _validateMemberInCommittee(pegoutInfo.committeeId);

        bytes32 kickoffTxid = _challenge.btcTx.inputs[Constants.CHALLENGE_VIN_REIMBURSEMENT_KICKOFF].txId;
        if (pegoutInfo.reimbursementKickoffTxid != kickoffTxid) {
            revert ReimbursementKickoffTxidNotMatch(kickoffTxid, pegoutInfo.reimbursementKickoffTxid);
        }

        // Calculate the transaction id for verification
        bytes32 txid = bitcoinManager.getBtcTxid(_challenge.btcTx);

        Stream memory stream = streamManager.getStreamById(streamInfo.streamId);

        // Verify the txid is part of the Merkle Root and has enough confirmations
        rbtcBridge.verifyTxConfirmations(
            stream.pegoutConfirmations,
            txid,
            _challenge.blockHash,
            _challenge.merkleBranchPath,
            _challenge.merkleBranchHashes
        );

        challengeTempInfo[_acceptPeginTxid] = ChallengeTempInfo({challengeTxid: txid, revealTxid: bytes32(0)});

        emit ChallengeRegistered(txid, _acceptPeginTxid, pegoutInfo.committeeId, streamInfo);

        streamManager.setPegStatus(_acceptPeginTxid, PegStatus.CHALLENGE);
    }

    function _validateMemberInCommittee(uint128 _committeeId) internal view {
        address _memberAddress = _msgSender();
        bool inCommittee = committeeRegistry.isMemberInCommittee(_committeeId, _memberAddress);
        if (!inCommittee) {
            revert ICommitteeRegistry.MemberNotInCommittee(_committeeId, _memberAddress);
        }
    }

    /// @inheritdoc IChallengeManager
    function registerInputRevealed(bytes32 _acceptPeginTxid, BtcTxSPVProof memory _inputRevealed)
        external
        nonReentrant
        whenNotPaused
    {
        StreamPosition memory streamInfo = _validatePegStatus(_acceptPeginTxid, PegStatus.CHALLENGE);

        if (_inputRevealed.btcTx.inputs.length != Constants.INPUT_REVEALED_INPUT_COUNT) {
            revert InvalidRevealedInputCount(_inputRevealed.btcTx.inputs.length, Constants.INPUT_REVEALED_INPUT_COUNT);
        }

        PegoutTempInfo memory pegoutInfo = pegoutManager.getPegoutTempInfo(_acceptPeginTxid);
        _validateMemberInCommittee(pegoutInfo.committeeId);

        ChallengeTempInfo storage challengeInfo = challengeTempInfo[_acceptPeginTxid];
        bytes32 challengeTxid = _inputRevealed.btcTx.inputs[Constants.INPUT_REVEALED_VIN_CHALLENGE].txId;
        if (challengeInfo.challengeTxid != challengeTxid) {
            revert ChallengeTxidNotMatch(challengeTxid, challengeInfo.challengeTxid);
        }

        // Calculate the transaction id for verification
        bytes32 txid = bitcoinManager.getBtcTxid(_inputRevealed.btcTx);

        Stream memory stream = streamManager.getStreamById(streamInfo.streamId);

        // Verify the txid is part of the Merkle Root and has enough confirmations
        rbtcBridge.verifyTxConfirmations(
            stream.pegoutConfirmations,
            txid,
            _inputRevealed.blockHash,
            _inputRevealed.merkleBranchPath,
            _inputRevealed.merkleBranchHashes
        );

        challengeInfo.revealTxid = txid;
        emit RevealRegistered(txid, _acceptPeginTxid, pegoutInfo.committeeId, streamInfo);

        streamManager.setPegStatus(_acceptPeginTxid, PegStatus.REVEALED);
    }
}
