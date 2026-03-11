// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {PegManagerBase} from "./PegManagerBase.sol";
import {IPeginManager, RequestPeginTempInfo} from "./interfaces/IPeginManager.sol";
import {ICommitteeRegistry, CommitteeMember} from "./interfaces/ICommitteeRegistry.sol";
import {IMemberRegistry, MemberKeys, CompactPubKey} from "./interfaces/IMemberRegistry.sol";
import {IStreamManager, Stream} from "./interfaces/IStreamManager.sol";
import {IBitcoinManager, PrevoutData, BitcoinSignatureData, BtcTxOut} from "./interfaces/IBitcoinManager.sol";
import {BtcTxSPVProof, StreamPosition, PegStatus} from "./interfaces/IPegCommonTypes.sol";
import {BtcHelper} from "./libraries/BtcHelper.sol";
import {Constants} from "./libraries/Constants.sol";
import {IRbtcBridge} from "./interfaces/IRbtcBridge.sol";
import {ISignatureManager} from "./interfaces/ISignatureManager.sol";

/// @title PeginManager
/// @notice Manages peg-in operations from Bitcoin to Rootstock
contract PeginManager is IPeginManager, PegManagerBase {
    mapping(bytes32 requestPeginTxid => bytes32 acceptPeginTxid) internal acceptPegins;

    mapping(bytes32 requestPeginTxid => RequestPeginTempInfo tempInfo) internal peginTempInfo;

    /// @notice Initializes the PeginManager contract
    /// @param _initialOwner The initial owner of the contract
    /// @param _accessManager The access manager contract address
    /// @param _committeeRegistry The committee registry contract address
    /// @param _bitcoinManager The Bitcoin manager contract address
    /// @param _rbtcBridge The RbtcBridge contract for minting RBTC
    /// @param _streamManager The stream manager contract address
    /// @param _signatureManager The signature manager contract address
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

    /// @inheritdoc IPeginManager
    function getAcceptPegin(bytes32 _requestPeginTxid) external view returns (bytes32) {
        return acceptPegins[_requestPeginTxid];
    }

    /// @inheritdoc IPeginManager
    function getRequestPeginTempInfo(bytes32 _btcTxid) external view returns (RequestPeginTempInfo memory) {
        return peginTempInfo[_btcTxid];
    }

    /// @inheritdoc IPeginManager
    function getRequestPeginData(address _rootstockDepositAddress, uint64 _value, bytes32 _btcReimbursementPubKey)
        external
        view
        returns (
            string memory bitcoinDepositAddress,
            uint64 packetNumber,
            CompactPubKey[] memory memberDisputeKeys,
            uint64 availableSlots
        )
    {
        // Validate Union Bridge locking cap
        if (_value > rbtcBridge.getUnionBridgeLockingCap()) {
            revert BridgeExceededLockingCap(_value, rbtcBridge.getUnionBridgeLockingCap());
        }

        // Get the stream for this value
        Stream memory stream = streamManager.getStream(_value);

        // Get the current packet's committee ID and key
        uint128 committeeId = streamManager.getCommitteeId(stream.streamId, stream.peginPacketPointer);
        bytes memory committeeKey = committeeRegistry.getCommitteeTakePubKey(committeeId);

        // Get the committee members
        CommitteeMember[] memory committeeMembers = committeeRegistry.getCommitteeMembers(committeeId);

        // Extract dispute keys (covenant keys) from each member
        memberDisputeKeys = new CompactPubKey[](committeeMembers.length);
        IMemberRegistry memberRegistry = committeeRegistry.memberRegistry();
        for (uint256 i = 0; i < committeeMembers.length; i++) {
            // slither-disable-next-line calls-loop
            memberDisputeKeys[i] = memberRegistry.getMemberPublicKeys(committeeMembers[i].memberAddress).disputePubKey;
        }

        return (
            bitcoinManager.getTemporaryPeginAddress(
                stream.timelockSettings.requestPeginTimelock,
                _rootstockDepositAddress,
                _value,
                _btcReimbursementPubKey,
                committeeKey
            ),
            stream.peginPacketPointer,
            memberDisputeKeys,
            Constants.SLOTS_PER_PACKET - streamManager.getPacketSlotsLength(stream.streamId, stream.peginPacketPointer)
        );
    }

    /// @inheritdoc IPeginManager
    function requestPegin(BtcTxSPVProof memory _requestPeginTxSPVProof) external nonReentrant whenNotPaused {
        bytes32 requestPeginTxid = _validateRequestPeginProof(_requestPeginTxSPVProof);

        (
            uint64 packetNumber,
            address rskDestinationAddress,
            bytes32 btcReimbursementPubKey,
            uint128 committeeId,
            Stream memory stream,
            bytes memory committeePubKey
        ) = _validatePeginP2TRAndOpReturn(_requestPeginTxSPVProof);

        // Fetch the enabler scriptPubKey from the packet (calculated during packet creation)
        bytes memory enablerScriptPubKey = streamManager.getEnablerScriptPubKey(stream.streamId, packetNumber);

        (int256 blockNumber, BitcoinSignatureData memory acceptPeginSignatureData) = _validatePeginEnablerAndBlockNumber(
            _requestPeginTxSPVProof,
            btcReimbursementPubKey,
            committeePubKey,
            enablerScriptPubKey,
            stream,
            requestPeginTxid,
            committeeId
        );

        // Store temp info before external calls
        RequestPeginTempInfo memory requestPeginInfo = RequestPeginTempInfo({
            rskDestinationAddress: rskDestinationAddress,
            btcReimbursementPubKey: btcReimbursementPubKey,
            acceptPeginSignatureHash: acceptPeginSignatureData.signatureHash,
            btcBlockNumber: blockNumber,
            userReimbursementTxid: bytes32(0),
            rejectPeginTxid: bytes32(0)
        });
        peginTempInfo[requestPeginTxid] = requestPeginInfo;

        // Store request mapping before external calls
        acceptPegins[requestPeginTxid] = acceptPeginSignatureData.txid;

        StreamPosition memory streamPos = _reserveSlot(stream.streamId, packetNumber, acceptPeginSignatureData.txid);

        // Check if we need a new packet/committee
        if (streamPos.slotId == Constants.SLOT_USAGE_THRESHOLD - 1) {
            committeeRegistry.createCommittee(stream.streamId);
        }

        if (streamPos.slotId >= Constants.SLOT_USAGE_THRESHOLD) {
            if (committeeRegistry.isPendingCommitteeExpired(stream.streamId)) {
                committeeRegistry.createCommittee(stream.streamId);
            }
        }

        // slither-disable-next-line reentrancy-events
        emit PeginRequested(
            committeeId,
            requestPeginTxid,
            acceptPeginSignatureData.txid,
            streamPos,
            requestPeginInfo,
            acceptPeginSignatureData.signatureMessage
        );

        // Final external calls - moved to end to minimize reentrancy attack surface
        // slither-disable-next-line reentrancy-no-eth reentrancy-benign
        signatureManager.initSignatures(acceptPeginSignatureData.txid, committeeId);
        // slither-disable-next-line reentrancy-no-eth reentrancy-benign
        signatureManager.initOperatorTakeTxids(acceptPeginSignatureData.txid, committeeId);
    }

    function _validateRequestPeginProof(BtcTxSPVProof memory _requestPeginTxSPVProof)
        internal
        view
        returns (bytes32 requestPeginTxid)
    {
        if (_requestPeginTxSPVProof.btcTx.version != Constants.BTC_TX_VERSION) {
            revert InvalidBtcTxVersion(_requestPeginTxSPVProof.btcTx.version, Constants.BTC_TX_VERSION);
        }

        if (_requestPeginTxSPVProof.btcTx.locktime != Constants.LOCKTIME) {
            revert InvalidLocktime(_requestPeginTxSPVProof.btcTx.locktime, Constants.LOCKTIME);
        }

        // Calculate requestPeginTxid from BtcTransaction
        requestPeginTxid = bitcoinManager.getBtcTxid(_requestPeginTxSPVProof.btcTx);
        if (_getStreamPositionByRequestPegin(requestPeginTxid).pegStatus != PegStatus.NOT_REGISTERED) {
            revert PeginAlreadyRequested(requestPeginTxid);
        }

        // Validate transaction has at least 2 outputs
        if (_requestPeginTxSPVProof.btcTx.outputs.length < 2) {
            revert IncorrectOutputsNumber(uint64(_requestPeginTxSPVProof.btcTx.outputs.length), 2);
        }
    }

    function _validatePeginP2TRAndOpReturn(BtcTxSPVProof memory _requestPeginTxSPVProof)
        internal
        view
        returns (
            uint64 packetNumber,
            address rskDestinationAddress,
            bytes32 btcReimbursementPubKey,
            uint128 committeeId,
            Stream memory stream,
            bytes memory committeePubKey
        )
    {
        // Second transaction should be OP_RETURN with data
        (packetNumber, rskDestinationAddress, btcReimbursementPubKey) = bitcoinManager.getPeginOpReturnData(
            _requestPeginTxSPVProof.btcTx.outputs[Constants.REQUEST_PEGIN_VOUT_OP_RETURN]
        );

        // First transaction is the Pegin P2TR _requestPeginTxSPVProof.btcTx.outputs[0]
        // Get corresponding stream for the amount if non found reverts
        stream =
            streamManager.getStream(_requestPeginTxSPVProof.btcTx.outputs[Constants.REQUEST_PEGIN_VOUT_TAPTREE].amount);

        committeeId = streamManager.getCommitteeId(stream.streamId, packetNumber);
        // getCommitteeTakePubKey reverts if committee does not exist
        committeePubKey = committeeRegistry.getCommitteeTakePubKey(committeeId);

        // Validates that the Taproot Script has a Key Path for the committeePubKey
        // and has a timelock for btcReimbursementPubKey
        bitcoinManager.validateRequestPeginP2TROutput(
            stream.timelockSettings.requestPeginTimelock,
            rskDestinationAddress,
            stream.denomination,
            btcReimbursementPubKey,
            committeePubKey,
            _requestPeginTxSPVProof.btcTx.outputs[Constants.REQUEST_PEGIN_VOUT_TAPTREE]
        );
    }

    function _validatePeginEnablerAndBlockNumber(
        BtcTxSPVProof memory _requestPeginTxSPVProof,
        bytes32 _btcReimbursementPubKey,
        bytes memory _committeePubKey,
        bytes memory _enablerScriptPubKey,
        Stream memory _stream,
        bytes32 _requestPeginTxid,
        uint128 _committeeId
    ) internal view returns (int256 blockNumber, BitcoinSignatureData memory acceptPeginSignatureData) {
        // Validates the enabler output (vout 2) with the correct amount and scriptPubKey
        bitcoinManager.validateRequestPeginEnablerOutput(
            _enablerScriptPubKey, _requestPeginTxSPVProof.btcTx.outputs[Constants.REQUEST_PEGIN_VOUT_ENABLER]
        );

        // Verifies the requestPeginTxid part of the Merkle Root of Tx of a Block
        // and that block is inside Bitcoin Mainchain
        // and has enough confirmations
        blockNumber = rbtcBridge.getTxBlockNumberAndVerifyConfirmations(
            _stream.peginConfirmations,
            _requestPeginTxid,
            _requestPeginTxSPVProof.blockHash,
            _requestPeginTxSPVProof.merkleBranchPath,
            _requestPeginTxSPVProof.merkleBranchHashes
        );

        return (
            blockNumber,
            _calculateAcceptPeginSignatureData(
                _btcReimbursementPubKey,
                _committeeId,
                _requestPeginTxid,
                _requestPeginTxSPVProof,
                _committeePubKey,
                _enablerScriptPubKey
            )
        );
    }

    function _calculateAcceptPeginSignatureData(
        bytes32 _btcReimbursementPubKey,
        uint128 _committeeId,
        bytes32 _requestPeginTxid,
        BtcTxSPVProof memory _requestPeginTxSPVProof,
        bytes memory _committeePubKey,
        bytes memory _enablerScriptPubKey
    ) internal view returns (BitcoinSignatureData memory acceptPeginSignatureData) {
        // Pre-compute prevout data for both inputs before external calls to follow checks-effects-interactions
        PrevoutData[] memory prevoutDatas = new PrevoutData[](2);
        // First input: taptree output from request peg-in
        prevoutDatas[0] = PrevoutData({
            value: _requestPeginTxSPVProof.btcTx.outputs[Constants.REQUEST_PEGIN_VOUT_TAPTREE].amount,
            scriptPubKey: _requestPeginTxSPVProof.btcTx.outputs[Constants.REQUEST_PEGIN_VOUT_TAPTREE].scriptPubKey
        });
        // Second input: enabler output from request peg-in
        prevoutDatas[1] = PrevoutData({value: Constants.SPEED_UP_AMOUNT, scriptPubKey: _enablerScriptPubKey});
        // Get the members dispute keys of the committee
        CompactPubKey[] memory membersDisputeKeys = committeeRegistry.getCommitteeDisputeKeys(_committeeId);
        acceptPeginSignatureData = bitcoinManager.getAcceptPeginSignatureHash(
            _committeePubKey, _btcReimbursementPubKey, _requestPeginTxid, prevoutDatas, membersDisputeKeys
        );
    }

    function _reserveSlot(uint64 _streamId, uint64 packetNumber, bytes32 _txid)
        internal
        returns (StreamPosition memory streamPos)
    {
        // Reserve slot during request peg-in - external call
        // slither-disable-next-line reentrancy-no-eth reentrancy-benign
        uint64 slotId = streamManager.reserveSlot(_streamId, packetNumber);

        // Complete state updates after external call
        streamPos = StreamPosition({
            streamId: _streamId,
            packetNumber: packetNumber,
            slotId: slotId,
            pegStatus: PegStatus.REGISTERED
        });

        streamManager.setStreamPosition(_txid, streamPos);
        return streamPos;
    }

    /// @inheritdoc IPeginManager
    function userReimbursement(BtcTxSPVProof memory _userReimbursementTxSPVProof, uint32 _reimbursementPeginVin)
        external
        nonReentrant
        whenNotPaused
    {
        // the input should be the request peg-in txid
        bytes32 requestPeginTxid = _userReimbursementTxSPVProof.btcTx.inputs[_reimbursementPeginVin].txId;

        // Validate the peg in request tx exists and the status
        bytes32 acceptPeginTxid = acceptPegins[requestPeginTxid];
        StreamPosition memory streamInfo = streamManager.validatePeginStatus(acceptPeginTxid, PegStatus.REGISTERED);

        // Calculate userReimbursementTxid from BtcTransaction
        bytes32 userReimbursementTxid = bitcoinManager.getBtcTxid(_userReimbursementTxSPVProof.btcTx);

        // Validate the txid is NOT the same as the accept peg-in txid
        if (acceptPeginTxid == userReimbursementTxid) {
            revert InvalidUserReimbursementTx(userReimbursementTxid);
        }

        // Verify the user reimbursement transaction
        _verifyUserReimbursementTransaction(
            _userReimbursementTxSPVProof,
            requestPeginTxid,
            userReimbursementTxid,
            streamInfo.streamId,
            _reimbursementPeginVin
        );

        // Block slot as it has already been reimbursed to the user.
        // slither-disable-next-line reentrancy-no-eth reentrancy-benign
        _blockSlot(streamInfo, acceptPeginTxid);

        // Set user reimbursement txid as rejected peg-in txid
        peginTempInfo[requestPeginTxid].userReimbursementTxid = userReimbursementTxid;

        emit UserReimbursementRegistered(userReimbursementTxid, requestPeginTxid, streamInfo);
    }

    function _verifyUserReimbursementTransaction(
        BtcTxSPVProof memory _userReimbursementTxSPVProof,
        bytes32 _requestPeginTxid,
        bytes32 _userReimbursementTxid,
        uint64 _streamId,
        uint32 _reimbursementPeginVin
    ) internal view {
        // Valdate the vout is correct
        if (
            _userReimbursementTxSPVProof.btcTx.inputs[_reimbursementPeginVin].vout
                != Constants.REQUEST_PEGIN_VOUT_TAPTREE
        ) {
            revert IncorrectVout(
                _userReimbursementTxSPVProof.btcTx.inputs[_reimbursementPeginVin].vout,
                Constants.REQUEST_PEGIN_VOUT_TAPTREE
            );
        }

        Stream memory stream = streamManager.getStreamById(_streamId);

        // Verify the userReimbursementTxid part of the Merkle Root of Tx of a Block
        // and that block is inside Bitcoin Mainchain
        // and has enough confirmations
        int256 blockNumber = rbtcBridge.getTxBlockNumberAndVerifyConfirmations(
            stream.peginConfirmations,
            _userReimbursementTxid,
            _userReimbursementTxSPVProof.blockHash,
            _userReimbursementTxSPVProof.merkleBranchPath,
            _userReimbursementTxSPVProof.merkleBranchHashes
        );

        int256 blocksElapsedSinceRequestPegin = blockNumber - peginTempInfo[_requestPeginTxid].btcBlockNumber;

        if (blocksElapsedSinceRequestPegin < int256(uint256(stream.timelockSettings.requestPeginTimelock))) {
            revert UserReimbursementBeforeTimelock(
                blocksElapsedSinceRequestPegin, stream.timelockSettings.requestPeginTimelock
            );
        }
    }

    /// @inheritdoc IPeginManager
    function rejectPegin(BtcTxSPVProof memory _rejectPeginTxSPVProof) external nonReentrant whenNotPaused {
        // the input index should be the request peg-in txid
        bytes32 requestPeginTxid = _rejectPeginTxSPVProof.btcTx.inputs[Constants.REJECT_PEGIN_VIN_ENABLER].txId;

        // Validate the peg in request tx exists and the status
        bytes32 acceptPeginTxid = acceptPegins[requestPeginTxid];
        StreamPosition memory streamInfo = streamManager.validatePeginStatus(acceptPeginTxid, PegStatus.REGISTERED);

        // Calculate userReimbursementTxid from BtcTransaction
        bytes32 rejectPeginTxid = bitcoinManager.getBtcTxid(_rejectPeginTxSPVProof.btcTx);

        // Validate the txid is NOT the same as the accept peg-in txid
        if (acceptPeginTxid == rejectPeginTxid) {
            revert InvalidRejectPeginTxid(rejectPeginTxid);
        }

        // Verify the pegin rejected transaction
        _verifyRejectPeginTransaction(_rejectPeginTxSPVProof, rejectPeginTxid, streamInfo.streamId);

        // Set user reimbursement txid as rejected peg-in txid
        peginTempInfo[requestPeginTxid].rejectPeginTxid = rejectPeginTxid;

        emit RejectPeginRegistered(rejectPeginTxid, requestPeginTxid, streamInfo);

        // Block slot as it has already been rejected.
        _blockSlot(streamInfo, acceptPeginTxid);
    }

    function _blockSlot(StreamPosition memory _streamInfo, bytes32 _acceptPeginTxid) internal {
        bool packetClosed = streamManager.blockSlot(_acceptPeginTxid);
        if (packetClosed) {
            committeeRegistry.releaseCommittee(_streamInfo.streamId, _streamInfo.packetNumber);
        }
    }

    function _verifyRejectPeginTransaction(
        BtcTxSPVProof memory _rejectPeginTxSPVProof,
        bytes32 _rejectPeginTxid,
        uint64 _streamId
    ) internal view {
        // Valdate the vout is correct
        if (
            _rejectPeginTxSPVProof.btcTx.inputs[Constants.REJECT_PEGIN_VIN_ENABLER].vout
                != Constants.REQUEST_PEGIN_VOUT_ENABLER
        ) {
            revert IncorrectVout(
                _rejectPeginTxSPVProof.btcTx.inputs[Constants.REJECT_PEGIN_VIN_ENABLER].vout,
                Constants.REQUEST_PEGIN_VOUT_ENABLER
            );
        }

        Stream memory stream = streamManager.getStreamById(_streamId);

        // Verify the userReimbursementTxid part of the Merkle Root of Tx of a Block
        // and that block is inside Bitcoin Mainchain
        // and has enough confirmations
        rbtcBridge.verifyTxConfirmations(
            stream.peginConfirmations,
            _rejectPeginTxid,
            _rejectPeginTxSPVProof.blockHash,
            _rejectPeginTxSPVProof.merkleBranchPath,
            _rejectPeginTxSPVProof.merkleBranchHashes
        );

        // TODO review if we should wait an amount of blocks before rejecting the peg-in
    }

    /// @inheritdoc IPeginManager
    function acceptPegin(BtcTxSPVProof memory _peginAcceptedTxSPVProof) external nonReentrant whenNotPaused {
        // The first input consumes the the peg in request utxo
        bytes32 requestPeginTxid = _peginAcceptedTxSPVProof.btcTx.inputs[Constants.REQUEST_PEGIN_VOUT_TAPTREE].txId;

        // Validate the peg in request tx exists and the status
        StreamPosition memory streamInfo = _getStreamPositionByRequestPegin(requestPeginTxid);
        if (streamInfo.pegStatus == PegStatus.NOT_REGISTERED) {
            revert PeginNotRequested(requestPeginTxid);
        }
        if (streamInfo.pegStatus != PegStatus.REGISTERED) {
            revert PeginAlreadyAccepted(requestPeginTxid);
        }

        // Calculate acceptPeginTxid from BtcTransaction
        bytes32 acceptPeginTxid = bitcoinManager.getBtcTxid(_peginAcceptedTxSPVProof.btcTx);

        // Validate the txid is the same calculated at request peg in tx
        if (acceptPegins[requestPeginTxid] != acceptPeginTxid) {
            revert InvalidAcceptPeginTxid(acceptPegins[requestPeginTxid], acceptPeginTxid);
        }

        // Verify the acceptPeginTxid part of the Merkle Root of Tx of a Block
        // and that block is inside Bitcoin Mainchain
        // annd has enough confirmations
        rbtcBridge.verifyTxConfirmations(
            streamManager.getStreamById(streamInfo.streamId).peginConfirmations,
            acceptPeginTxid,
            _peginAcceptedTxSPVProof.blockHash,
            _peginAcceptedTxSPVProof.merkleBranchPath,
            _peginAcceptedTxSPVProof.merkleBranchHashes
        );

        _storePegin(
            requestPeginTxid,
            _peginAcceptedTxSPVProof.blockHash,
            acceptPeginTxid,
            _peginAcceptedTxSPVProof.btcTx.outputs[Constants.ACCEPT_PEGIN_VOUT_TAPTREE]
        );
    }

    function _storePegin(
        bytes32 _requestPeginTxid,
        bytes32 _blockHash,
        bytes32 _acceptPeginTxid,
        BtcTxOut memory _acceptPeginTxOutput
    ) internal {
        // Update the peg in request status to ACCEPTED to avoid processing it again
        streamManager.setPegStatus(_acceptPeginTxid, PegStatus.ACCEPTED);
        StreamPosition memory stream = streamManager.getStreamPosition(_acceptPeginTxid);

        // Fill the reserved slot with accept peg-in transaction details
        streamManager.fillSlot(stream, _acceptPeginTxOutput.amount, _acceptPeginTxid, _acceptPeginTxOutput.scriptPubKey);

        uint256 rbtcAmount = BtcHelper.satoshiToWei(_acceptPeginTxOutput.amount);
        RequestPeginTempInfo storage requestTempInfo = peginTempInfo[_requestPeginTxid];

        // slither-disable-next-line reentrancy-events
        emit PeginAccepted(
            _blockHash,
            _acceptPeginTxid,
            _requestPeginTxid,
            Constants.ACCEPT_PEGIN_VOUT_TAPTREE,
            stream,
            requestTempInfo.btcReimbursementPubKey,
            requestTempInfo.rskDestinationAddress,
            rbtcAmount,
            _acceptPeginTxOutput.scriptPubKey
        );

        // Mint RBTC to the destination address via RbtcBridge
        rbtcBridge.mintRbtc(payable(requestTempInfo.rskDestinationAddress), rbtcAmount);
    }

    /// @inheritdoc IPeginManager
    function getStreamPositionByRequestPegin(bytes32 _requestPeginTxid) external view returns (StreamPosition memory) {
        return _getStreamPositionByRequestPegin(_requestPeginTxid);
    }

    /// @dev Internal helper to get stream position from request peg-in txid
    /// @param _requestPeginTxid The request peg-in transaction id
    /// @return The stream position information
    function _getStreamPositionByRequestPegin(bytes32 _requestPeginTxid)
        internal
        view
        returns (StreamPosition memory)
    {
        bytes32 acceptPeginTxid = acceptPegins[_requestPeginTxid];
        return streamManager.getStreamPosition(acceptPeginTxid);
    }
}
