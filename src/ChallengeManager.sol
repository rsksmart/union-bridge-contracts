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

/// @title ChallengeManager
/// @notice Manages challenge operations
contract ChallengeManager is IChallengeManager, PegBase {
    /// @notice The PegoutManager contract
    IPegoutManager public pegoutManager;

    /// @notice Temporary information stored during challenge processing
    /// @dev Contains data needed for challenge transaction validation
    mapping(bytes32 acceptPeginTxid => ChallengeTempInfo tempInfo) internal challengeTempInfo;

    /// @notice Gets the temporary challenge information for a given accept peg-in transaction id
    /// @param _acceptPeginTxid The accept peg-in transaction id
    /// @return The temporary challenge information
    function getChallengeTempInfo(bytes32 _acceptPeginTxid) external view returns (ChallengeTempInfo memory) {
        return challengeTempInfo[_acceptPeginTxid];
    }

    /// @notice Initializes the ChallengeManager contract
    /// @param _initialOwner The initial owner of the contract
    /// @param _bridgeAddress The address of the pow-peg bridge contract
    /// @param _accessManager The access manager contract address
    /// @param _committeeRegistry The committee registry contract address
    /// @param _bitcoinManager The Bitcoin manager contract address
    /// @param _pegoutManager The pegout manager contract address
    /// @param _streamManager The stream manager contract address
    function initialize(
        address _initialOwner,
        address payable _bridgeAddress,
        address _accessManager,
        ICommitteeRegistry _committeeRegistry,
        IBitcoinManager _bitcoinManager,
        IPegoutManager _pegoutManager,
        IStreamManager _streamManager
    ) public initializer {
        __PegBase_init(
            _initialOwner, _bridgeAddress, _accessManager, _committeeRegistry, _bitcoinManager, _streamManager
        );
        if (address(_pegoutManager) == address(0)) {
            revert InvalidZeroAddress();
        }
        pegoutManager = _pegoutManager;
    }

    function registerChallenge(bytes32 _acceptPeginTxid, BtcTxSPVProof memory _challenge)
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
        _verifyTxConfirmations(
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
        _verifyTxConfirmations(
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
