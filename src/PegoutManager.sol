// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {PegManagerBase} from "./PegManagerBase.sol";
import {IPegoutManager, PegoutManagerSettings, PegoutTempInfo} from "./interfaces/IPegoutManager.sol";
import {ICommitteeRegistry} from "./interfaces/ICommitteeRegistry.sol";
import {SignatureData, OperatorTakeData} from "./interfaces/ISignatureManager.sol";
import {Stream, Slot} from "./interfaces/IStreamManager.sol";
import {IBitcoinManager, PrevoutData, BitcoinSignatureData} from "./interfaces/IBitcoinManager.sol";
import {BtcTxSPVProof, StreamPosition, PegStatus} from "./interfaces/IPegCommonTypes.sol";
import {BtcHelper} from "./libraries/BtcHelper.sol";
import {Constants} from "./libraries/Constants.sol";
import {IRbtcBridge} from "./interfaces/IRbtcBridge.sol";

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
    /// @param _bridgeAddress The address of the pow-peg bridge contract
    /// @param _committeeRegistry The committee registry contract address
    /// @param _bitcoinManager The Bitcoin manager contract address
    /// @param _settings The peg manager settings including timeouts
    /// @param _rbtcBridge The RbtcBridge contract for burning RBTC
    /// @dev This function can only be called once during contract deployment
    function initialize(
        address _initialOwner,
        address payable _bridgeAddress,
        ICommitteeRegistry _committeeRegistry,
        IBitcoinManager _bitcoinManager,
        PegoutManagerSettings memory _settings,
        IRbtcBridge _rbtcBridge
    ) public virtual initializer {
        __PegManagerBase_init(_initialOwner, _bridgeAddress, _committeeRegistry, _bitcoinManager, _rbtcBridge);

        userTakeTimeout = _settings.userTakeTimeout;
        operatorTakeTimeout = _settings.operatorTakeTimeout;
    }

    /// @notice Gets the temporary peg-out information for a given accept peg-in transaction id
    /// @param _acceptPeginTxid The accept peg-in transaction id
    /// @return The temporary peg-out information
    function getPegoutTempInfo(bytes32 _acceptPeginTxid) external view returns (PegoutTempInfo memory) {
        return pegoutTempInfo[_acceptPeginTxid];
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

    /// @notice Initiates a peg-out operation by locking a slot and preparing the peg-out transaction
    /// @param _userPubKey The user's compressed public key for the Bitcoin output
    /// @dev This function LOCKS a slot in the appropriate stream and prepares the peg-out transaction
    /// @dev The user must send the exact amount of RBTC they want to peg-out
    /// @dev Emits the PegoutRequested event
    /// @dev Only callable when contract is unpaused
    function tryPegout(bytes memory _userPubKey) external payable nonReentrant whenNotPaused {
        _validatePegoutRequest(_userPubKey, msg.value);

        Stream memory stream = streamManager.getStream(uint64(BtcHelper.weiToSatoshi(msg.value)));
        // slither-disable-next-line reentrancy-benign
        (Slot memory slot, uint64 packetNumber) = streamManager.lockSlot(stream.streamId);

        PrevoutData[] memory prevoutDatas = _preparePegoutPrevoutDatas(slot);

        // Compute the Bitcoin peg-out signature hash
        BitcoinSignatureData memory pegoutSignatureData =
            bitcoinManager.getPegoutTxData(_userPubKey, slot.acceptPeginTx, prevoutDatas);

        uint128 committeeId =
            _storePegoutAndInitSignatures(pegoutSignatureData.txid, stream.streamId, packetNumber, slot.slotId);

        // Store the pegout to pegin tx id mapping
        pegoutToPeginTxid[pegoutSignatureData.txid] = slot.acceptPeginTx;

        // Burn RBTC back to PowPeg bridge via RbtcBridge
        // We burn the amount that was actually minted (acceptPeginAmount), not msg.value
        // The difference (fees) remains in the contract for future operator fee distribution
        uint256 amountToBurn = BtcHelper.satoshiToWei(slot.acceptPeginAmount);
        rbtcBridge.burnRbtc{value: amountToBurn}();

        // Compute pegout ID
        bytes32 pegoutId = keccak256(
            abi.encode(
                stream.streamId,
                packetNumber,
                slot.slotId,
                _msgSender(),
                BtcHelper.hash256(bridge.getBtcBlockchainBestBlockHeader())
            )
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
            reimbursementKickoffTxid: bytes32(0),
            challengeTxid: bytes32(0),
            revealTxid: bytes32(0)
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
    }

    /// @notice Register a peg-out transaction from Bitcoin
    /// @param _pegoutTxSPVProof The BTC SPV proof of the peg-out transaction
    /// @dev This function validates the peg-out transaction and marks the slot as COMPLETED
    /// @dev The transaction must spend the accept peg-in output and pay to the user's address
    /// @dev Emits the PegoutRegistered event
    /// @dev Only callable when contract is unpaused
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
        _verifyTxConfirmations(
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

        // Update slot status
        streamManager.completeSlot(
            streamInfo.streamId, streamInfo.packetNumber, streamInfo.slotId, acceptPeginTxid, requestPegoutTxid
        );

        // If it's the last slot in the package, close and release the committee
        _closePacketIfLastSlot(streamInfo);
    }

    /// @notice Gets the peg-out signature hash for a specific stream, packet, and slot
    /// @param streamId The stream identifier
    /// @param packetNumber The packet number within the stream
    /// @param slotId The slot identifier within the packet
    /// @return The peg-out signature hash
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

    /// @notice Triggers the operator take process for a peg-out when not all committee members sign within timeout
    /// @dev This function can be called after a User Take expiration or after an Operator Take expiration
    /// @dev Each case has its own timeout and before triggering the operator take (after a User Take expiration)
    /// @dev signatures should be checked to see if the User Take was already signed
    /// @dev Partial signatures are used to skip those operators that have not signed the User Take
    /// @dev Emits OperatorTakeTriggered event upon successful triggering
    /// @dev Only callable when contract is unpaused
    /// @param _pegoutTxid The transaction id of the peg-out request
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

    function registerAdvanceFunds(bytes32 acceptPeginTxid, BtcTxSPVProof memory _advanceFunds)
        external
        nonReentrant
        whenNotPaused
    {
        StreamPosition memory streamInfo = _validatePegStatus(acceptPeginTxid, PegStatus.OP_SELECTED);

        PegoutTempInfo storage pegoutInfo = _validateOperatorTakeAddress(acceptPeginTxid);

        (bytes32 txid, int256 confirmations) = _verifyAdvanceFundsTx(_advanceFunds, pegoutInfo, streamInfo.streamId);

        // update the peg status to ADVANCED
        streamManager.setPegStatus(acceptPeginTxid, PegStatus.ADVANCED);

        // Update advance funds block number
        pegoutInfo.advanceFundsBlockNumber = _getBlockNumberFromConfirmations(confirmations);

        // slither-disable-next-line reentrancy-events
        emit AdvanceFundsRegistered(
            _advanceFunds.blockHash, txid, acceptPeginTxid, pegoutInfo.pegoutId, pegoutInfo.committeeId, streamInfo
        );
    }

    function _verifyAdvanceFundsTx(
        BtcTxSPVProof memory _advanceFunds,
        PegoutTempInfo memory _pegoutInfo,
        uint64 _streamId
    ) internal view returns (bytes32 txid, int256 confirmations) {
        // Calculate the transaction id for verification
        txid = bitcoinManager.getBtcTxid(_advanceFunds.btcTx);

        // Get the stream to check confirmations
        Stream memory stream = streamManager.getStreamById(_streamId);

        // Verify the txid is part of the Merkle Root and has enough confirmations
        confirmations = _verifyTxConfirmations(
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

    function _validateMemberInCommittee(uint128 _committeeId) internal view {
        address _memberAddress = _msgSender();
        bool inCommittee = committeeRegistry.isMemberInCommittee(_committeeId, _memberAddress);
        if (!inCommittee) {
            revert ICommitteeRegistry.MemberNotInCommittee(_committeeId, _memberAddress);
        }
    }

    function registerReimbursementKickoff(bytes32 acceptPeginTxid, BtcTxSPVProof memory _kickoffSPV)
        external
        nonReentrant
        whenNotPaused
    {
        StreamPosition memory streamInfo = _validatePegStatus(acceptPeginTxid, PegStatus.ADVANCED);

        PegoutTempInfo storage pegoutInfo = _validateOperatorTakeAddress(acceptPeginTxid);

        // Calculate the transaction id for verification
        bytes32 txid = bitcoinManager.getBtcTxid(_kickoffSPV.btcTx);

        Stream memory stream = streamManager.getStreamById(streamInfo.streamId);

        // Verify the txid is part of the Merkle Root and has enough confirmations
        int256 confirmations = _verifyTxConfirmations(
            stream.pegoutConfirmations,
            txid,
            _kickoffSPV.blockHash,
            _kickoffSPV.merkleBranchPath,
            _kickoffSPV.merkleBranchHashes
        );

        int256 blockNumber = _getBlockNumberFromConfirmations(confirmations);

        if (blockNumber < pegoutInfo.advanceFundsBlockNumber) {
            revert ReimbursementKickoffBeforeAdvanceFunds(pegoutInfo.advanceFundsBlockNumber, blockNumber);
        }

        // Update the reimbursement kickoff txid
        pegoutInfo.reimbursementKickoffTxid = txid;

        // update the peg status to KICKOFF
        streamManager.setPegStatus(acceptPeginTxid, PegStatus.KICKOFF);

        emit ReimbursementKickoffRegistered(txid, acceptPeginTxid, pegoutInfo.committeeId, streamInfo);
    }

    /// @notice Deposits an operator take proof for a peg-out transaction
    /// @param _pegoutTxSPVProof The BTC SPV proof of the operator take peg-out transaction
    /// @dev Validates the SPV proof and marks the slot as paid when operator takes over
    /// @dev Only callable when the peg status is OPERATOR_TAKE
    /// @dev Emits PegoutRegistered event upon successful deposit
    /// @dev Only callable when contract is unpaused
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

        OperatorTakeData[] memory opTakeData = signatureManager.getOperatorTakeData(acceptPeginTxid);

        uint256 memberIndex = 0;
        bool found = false;
        for (uint256 i = 0; i < opTakeData.length; i++) {
            if (opTakeData[i].memberAddress == pegoutInfo.takeOperatorAddress) {
                memberIndex = i;
                found = true;
                break;
            }
        }

        if (!found || opTakeData[memberIndex].takeTxid == bytes32(0)) {
            revert OperatorTakeDataNotFound(acceptPeginTxid, pegoutInfo.takeOperatorAddress);
        }

        // Validate operator take txid matched the one deposited during accept pegin
        if (txid != opTakeData[memberIndex].takeTxid) {
            revert OperatorTakeTxidNotMatch(txid, opTakeData[memberIndex].takeTxid);
        }

        // Get the stream to check confirmations
        Stream memory stream = streamManager.getStreamById(streamInfo.streamId);

        // Verify the txid is part of the Merkle Root and has enough confirmations
        _verifyTxConfirmations(
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

        // Update slot status
        streamManager.completeSlot(
            streamInfo.streamId, streamInfo.packetNumber, streamInfo.slotId, acceptPeginTxid, txid
        );

        // If it's the last slot in the package, close and release the committee
        _closePacketIfLastSlot(streamInfo);
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

        PegoutTempInfo storage pegoutInfo = pegoutTempInfo[_acceptPeginTxid];
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

        emit ChallengeRegistered(txid, _acceptPeginTxid, pegoutInfo.committeeId, streamInfo);

        pegoutInfo.challengeTxid = txid;
        streamManager.setPegStatus(_acceptPeginTxid, PegStatus.CHALLENGE);
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

        PegoutTempInfo storage pegoutInfo = pegoutTempInfo[_acceptPeginTxid];
        _validateMemberInCommittee(pegoutInfo.committeeId);

        bytes32 challengeTxid = _inputRevealed.btcTx.inputs[Constants.INPUT_REVEALED_VIN_CHALLENGE].txId;
        if (pegoutInfo.challengeTxid != challengeTxid) {
            revert ChallengeTxidNotMatch(challengeTxid, pegoutInfo.challengeTxid);
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

        emit RevealRegistered(txid, _acceptPeginTxid, pegoutInfo.committeeId, streamInfo);

        pegoutInfo.revealTxid = txid;
        streamManager.setPegStatus(_acceptPeginTxid, PegStatus.REVEALED);
    }

    /// @notice Sets the timeout duration for user take operations
    /// @param _timeout The new timeout duration in seconds
    /// @dev Only callable by the contract owner
    /// @dev Emits UserTakeTimeoutUpdated event upon successful update
    function setUserTakeTimeout(uint256 _timeout) external onlyOwner {
        if (_timeout == 0) {
            revert InvalidTimeout(_timeout);
        }
        userTakeTimeout = _timeout;
        emit UserTakeTimeoutUpdated(userTakeTimeout);
    }

    /// @notice Sets the timeout duration for operator take operations
    /// @param _timeout The new timeout duration in seconds
    /// @dev Only callable by the contract owner
    /// @dev Emits OperatorTakeTimeoutUpdated event upon successful update
    function setOperatorTakeTimeout(uint256 _timeout) external onlyOwner {
        if (_timeout == 0) {
            revert InvalidTimeout(_timeout);
        }
        operatorTakeTimeout = _timeout;
        emit OperatorTakeTimeoutUpdated(operatorTakeTimeout);
    }

    function _closePacketIfLastSlot(StreamPosition memory streamInfo) internal {
        // If it's the last slot in the package, close and release the committee
        if (streamInfo.slotId == Constants.SLOTS_PER_PACKET - 1) {
            emit PacketClosed(streamInfo.streamId, streamInfo.packetNumber);
            committeeRegistry.releaseCommittee(streamInfo.streamId, streamInfo.packetNumber);
        }
    }

    function _preparePegoutPrevoutDatas(Slot memory _slot) internal pure returns (PrevoutData[] memory) {
        PrevoutData[] memory prevoutDatas = new PrevoutData[](2);

        // Taptree prevout - read from slot
        prevoutDatas[0] = PrevoutData({value: _slot.acceptPeginAmount, scriptPubKey: _slot.scriptPubKey});

        // Enabler prevout - read from slot
        prevoutDatas[1] = PrevoutData({value: Constants.ENABLER_AMOUNT, scriptPubKey: _slot.enablerScriptPubKey});

        return prevoutDatas;
    }
}
