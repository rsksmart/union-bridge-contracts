// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {PegManagerBase} from "./PegManagerBase.sol";
import {IPeginManager, RequestPeginTempInfo} from "./interfaces/IPeginManager.sol";
import {ICommitteeRegistry, CommitteeMember} from "./interfaces/ICommitteeRegistry.sol";
import {IMemberRegistry, MemberKeys} from "./interfaces/IMemberRegistry.sol";
import {Stream} from "./interfaces/IStreamManager.sol";
import {IBitcoinManager, PrevoutData, BitcoinSignatureData, BtcTxOut} from "./interfaces/IBitcoinManager.sol";
import {BtcTxSPVProof, StreamPosition, PegStatus} from "./interfaces/IPegCommonTypes.sol";
import {BtcHelper} from "./libraries/BtcHelper.sol";
import {Constants} from "./libraries/Constants.sol";
import {IRbtcBridge} from "./interfaces/IRbtcBridge.sol";

/// @title PeginManager
/// @notice Manages peg-in operations from Bitcoin to Rootstock
contract PeginManager is IPeginManager, PegManagerBase {
    mapping(bytes32 requestPeginTxid => bytes32 acceptPeginTxid) internal acceptPegins;

    mapping(bytes32 requestPeginTxid => RequestPeginTempInfo tempInfo) internal peginTempInfo;

    /// @notice Initializes the PeginManager contract
    /// @param _initialOwner The initial owner of the contract
    /// @param _bridgeAddress The address of the pow-peg bridge contract
    /// @param _committeeRegistry The committee registry contract address
    /// @param _bitcoinManager The Bitcoin manager contract address
    /// @param _rbtcBridge The RbtcBridge contract for minting RBTC
    /// @dev This function can only be called once during contract deployment
    function initialize(
        address _initialOwner,
        address payable _bridgeAddress,
        ICommitteeRegistry _committeeRegistry,
        IBitcoinManager _bitcoinManager,
        IRbtcBridge _rbtcBridge
    ) public virtual initializer {
        __PegManagerBase_init(_initialOwner, _bridgeAddress, _committeeRegistry, _bitcoinManager, _rbtcBridge);
    }

    /// @notice Gets the accept peg-in transaction id for a given request peg-in transaction id
    /// @param _requestPeginTxid The request peg-in transaction id
    /// @return The accept peg-in transaction id
    function getAcceptPegin(bytes32 _requestPeginTxid) external view returns (bytes32) {
        return acceptPegins[_requestPeginTxid];
    }

    /// @notice Gets the temporary peg-in information for a given request peg-in transaction id
    /// @param _btcTxid The request peg-in transaction id
    /// @return The temporary peg-in information
    function getRequestPeginTempInfo(bytes32 _btcTxid) external view returns (RequestPeginTempInfo memory) {
        return peginTempInfo[_btcTxid];
    }

    /// @notice Generates request peg-in data including temporary Bitcoin address and member dispute keys
    /// @param _rootstockDepositAddress The Rootstock address where RBTC will be minted
    /// @param _value The amount in satoshis for determining the appropriate stream
    /// @param _btcReimbursementPubKey The Bitcoin public key for reimbursement transactions
    /// @return bitcoinDepositAddress The generated Bitcoin deposit address
    /// @return packetNumber The packet number for this peg-in request
    /// @return memberDisputeKeys Array of dispute keys (covenant keys) for each committee member in order
    /// @dev This address is used for the initial peg-in request transaction
    /// @dev The dispute keys are returned in the same order as committee members
    function getRequestPeginData(address _rootstockDepositAddress, uint64 _value, bytes32 _btcReimbursementPubKey)
        external
        view
        returns (
            string memory bitcoinDepositAddress,
            uint64 packetNumber,
            bytes32[] memory memberDisputeKeys,
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
        bytes memory committeeKey = streamManager.getCommitteePubKey(stream.streamId, stream.peginPacketPointer);

        // Get the committee members
        CommitteeMember[] memory committeeMembers = committeeRegistry.getCommitteeMembers(committeeId);

        // Extract dispute keys (covenant keys) from each member
        memberDisputeKeys = new bytes32[](committeeMembers.length);
        IMemberRegistry memberRegistry = committeeRegistry.memberRegistry();
        for (uint256 i = 0; i < committeeMembers.length; i++) {
            // slither-disable-next-line calls-loop
            MemberKeys memory keys = memberRegistry.getMemberPublicKeys(committeeMembers[i].memberAddress);
            memberDisputeKeys[i] = keys.covenantPubKey;
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

    /// @notice Requests a peg-in operation by providing an SPV proof of the Bitcoin transaction
    /// @param _requestPeginTxSPVProof The SPV proof containing the Bitcoin transaction and merkle proof
    /// @dev This function validates the peg-in request transaction and initiates the peg-in process
    /// @dev The transaction must have at least 2 outputs: one P2TR output and one OP_RETURN output
    /// @dev Emits the PeginRequested event
    /// @dev Only callable when contract is unpaused
    function requestPegin(BtcTxSPVProof calldata _requestPeginTxSPVProof) external nonReentrant whenNotPaused {
        bytes32 requestPeginTxid = _validateRequestPeginProof(_requestPeginTxSPVProof);

        (
            uint64 packetNumber,
            address rskDestinationAddress,
            bytes32 btcReimbursementPubKey,
            Stream memory stream,
            bytes memory committeePubKey
        ) = _extractPeginData(_requestPeginTxSPVProof);

        // Get committee ID and dispute keys before validation
        uint128 committeeId = streamManager.getCommitteeId(stream.streamId, packetNumber);
        bytes32[] memory disputeKeys = committeeRegistry.getCommitteeDisputeKeys(committeeId);

        _validatePeginTransaction(
            _requestPeginTxSPVProof,
            stream.timelockSettings.requestPeginTimelock,
            rskDestinationAddress,
            btcReimbursementPubKey,
            committeePubKey,
            disputeKeys,
            stream,
            requestPeginTxid
        );

        // Pre-compute prevout data for both inputs before external calls to follow checks-effects-interactions
        PrevoutData[] memory prevoutDatas = new PrevoutData[](2);
        // First input: taptree output from request peg-in
        prevoutDatas[0] = PrevoutData({
            value: _requestPeginTxSPVProof.btcTx.outputs[Constants.REQUEST_PEGIN_VOUT_TAPTREE].amount,
            scriptPubKey: _requestPeginTxSPVProof.btcTx.outputs[Constants.REQUEST_PEGIN_VOUT_TAPTREE].scriptPubKey
        });
        // Second input: enabler output from request peg-in
        prevoutDatas[1] = PrevoutData({
            value: Constants.SPEED_UP_AMOUNT,
            scriptPubKey: bitcoinManager.getEnablerOutputP2TRScriptPub(committeePubKey, disputeKeys)
        });

        bytes32[] memory operatorDisputeKeys = committeeRegistry.getOperatorDisputeKeys(committeeId);
        BitcoinSignatureData memory acceptPeginSignatureData = bitcoinManager.getAcceptPeginSignatureHash(
            committeePubKey, btcReimbursementPubKey, requestPeginTxid, prevoutDatas, operatorDisputeKeys
        );

        // Store temp info before external calls
        RequestPeginTempInfo memory requestPeginInfo = RequestPeginTempInfo({
            rskDestinationAddress: rskDestinationAddress,
            btcReimbursementPubKey: btcReimbursementPubKey,
            acceptPeginSignatureHash: acceptPeginSignatureData.signatureHash
        });
        peginTempInfo[requestPeginTxid] = requestPeginInfo;

        // Store request mapping before external calls
        acceptPegins[requestPeginTxid] = acceptPeginSignatureData.txid;

        // Reserve slot during request peg-in - external call
        // slither-disable-next-line reentrancy-no-eth reentrancy-benign
        uint64 slotId = streamManager.reserveSlot(stream.streamId, packetNumber);

        // Complete state updates after external call
        StreamPosition memory streamPos = StreamPosition({
            streamId: stream.streamId,
            packetNumber: packetNumber,
            slotId: slotId,
            pegStatus: PegStatus.REGISTERED
        });

        streamManager.setStreamPosition(acceptPeginSignatureData.txid, streamPos);

        // slither-disable-next-line reentrancy-events
        emit PeginRequested(
            committeeId,
            requestPeginTxid,
            acceptPeginSignatureData.txid,
            Constants.REQUEST_PEGIN_VOUT_TAPTREE,
            streamPos,
            requestPeginInfo,
            prevoutDatas[0], // Prevout data for taptree output (first input)
            acceptPeginSignatureData.signatureMessage
        );

        // Final external calls - moved to end to minimize reentrancy attack surface
        // slither-disable-next-line reentrancy-no-eth reentrancy-benign
        signatureManager.initSignatures(acceptPeginSignatureData.txid, committeeId);
        // slither-disable-next-line reentrancy-no-eth reentrancy-benign
        signatureManager.initOperatorTakeTxids(acceptPeginSignatureData.txid, committeeId);
    }

    function _validateRequestPeginProof(BtcTxSPVProof calldata _requestPeginTxSPVProof)
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

    function _extractPeginData(BtcTxSPVProof calldata _requestPeginTxSPVProof)
        internal
        view
        returns (
            uint64 packetNumber,
            address rskDestinationAddress,
            bytes32 btcReimbursementPubKey,
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

        // getCommitteePubKey reverts if packet does not exist
        committeePubKey = streamManager.getCommitteePubKey(stream.streamId, packetNumber);
    }

    function _validatePeginTransaction(
        BtcTxSPVProof calldata _requestPeginTxSPVProof,
        uint32 _timelockBlocks,
        address rskDestinationAddress,
        bytes32 btcReimbursementPubKey,
        bytes memory committeePubKey,
        bytes32[] memory disputeKeys,
        Stream memory stream,
        bytes32 requestPeginTxid
    ) internal view {
        // Validates that the Taproot Script has a Key Path for the committeePubKey
        // and has a timelock for btcReimbursementPubKey
        bitcoinManager.validateRequestPeginP2TROutput(
            _timelockBlocks,
            rskDestinationAddress,
            stream.denomination,
            btcReimbursementPubKey,
            committeePubKey,
            _requestPeginTxSPVProof.btcTx.outputs[Constants.REQUEST_PEGIN_VOUT_TAPTREE]
        );

        // Validates the enabler output (vout 2) with the correct amount and scriptPubKey
        bitcoinManager.validateRequestPeginEnablerOutput(
            committeePubKey, disputeKeys, _requestPeginTxSPVProof.btcTx.outputs[Constants.REQUEST_PEGIN_VOUT_ENABLER]
        );

        // Verifies the requestPeginTxid part of the Merkle Root of Tx of a Block
        // and that block is inside Bitcoin Mainchain
        // and has enough confirmations
        _verifyTxConfirmations(
            stream.peginConfirmations,
            requestPeginTxid,
            _requestPeginTxSPVProof.blockHash,
            _requestPeginTxSPVProof.merkleBranchPath,
            _requestPeginTxSPVProof.merkleBranchHashes
        );
    }

    /// @notice Registers a user reimbursement transaction from Bitcoin
    /// @param _userReimbursementTxSPVProof The BTC SPV proof of the user reimbursement transaction
    /// @param _reimbursementPeginVin The input index of the reimbursement peg-in transaction
    /// @dev This function validates the user reimbursement transaction, it must spend the output from the request peg-in transaction
    /// @dev Updates the stream position to USER_TAKE and stores the user reimbursement transaction in the stream
    /// @dev Emits UserReimbursementRegistered event upon successful registration
    /// @dev Only callable when contract is unpaused
    function registerUserReimbursement(
        BtcTxSPVProof calldata _userReimbursementTxSPVProof,
        uint32 _reimbursementPeginVin
    ) external nonReentrant whenNotPaused {
        // the input should be the request peg-in txid
        bytes32 requestPeginTxid = _userReimbursementTxSPVProof.btcTx.inputs[_reimbursementPeginVin].txId;

        // Validate the peg in request tx exists and the status
        StreamPosition memory streamInfo = _getStreamPositionByRequestPegin(requestPeginTxid);
        if (streamInfo.pegStatus != PegStatus.REGISTERED) {
            revert InvalidPegStatus(requestPeginTxid, streamInfo.pegStatus, PegStatus.REGISTERED);
        }

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
        // Calculate userReimbursementTxid from BtcTransaction
        bytes32 userReimbursementTxid = bitcoinManager.getBtcTxid(_userReimbursementTxSPVProof.btcTx);

        // Validate the txid is NOT the same as the accept peg-in txid
        bytes32 acceptPeginTxid = acceptPegins[requestPeginTxid];
        if (acceptPeginTxid == userReimbursementTxid) {
            revert InvalidUserReimbursementTx(userReimbursementTxid);
        }

        // Verify the userReimbursementTxid part of the Merkle Root of Tx of a Block
        // and that block is inside Bitcoin Mainchain
        // annd has enough confirmations
        _verifyTxConfirmations(
            streamManager.getStreamById(streamInfo.streamId).peginConfirmations,
            userReimbursementTxid,
            _userReimbursementTxSPVProof.blockHash,
            _userReimbursementTxSPVProof.merkleBranchPath,
            _userReimbursementTxSPVProof.merkleBranchHashes
        );

        // Block slot as it has already been reimbursted to the user.
        // slither-disable-next-line reentrancy-no-eth reentrancy-benign
        streamManager.blockSlot(streamInfo.streamId, streamInfo.packetNumber, streamInfo.slotId);
        streamManager.setPegStatus(acceptPeginTxid, PegStatus.BLOCKED);

        emit UserReimbursementRegistered(userReimbursementTxid, requestPeginTxid, streamInfo);
    }

    /// @notice Accepts a peg-in operation by providing an SPV proof of the accept peg-in transaction
    /// @param _peginAcceptedTxSPVProof The SPV proof containing the accept peg-in Bitcoin transaction
    /// @dev This function validates the accept peg-in transaction, it must spend the output from the request peg-in transaction
    /// @dev Updates the stream position to ACCEPTED and stores the peg-in transaction in the stream
    /// @dev Emits the PeginAccepted event
    /// @dev Only callable when contract is unpaused
    function acceptPegin(BtcTxSPVProof calldata _peginAcceptedTxSPVProof) external nonReentrant whenNotPaused {
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
        _verifyTxConfirmations(
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
            _peginAcceptedTxSPVProof.btcTx.outputs[Constants.ACCEPT_PEGIN_VOUT_TAPTREE],
            _peginAcceptedTxSPVProof.btcTx.outputs[Constants.ACCEPT_PEGIN_VOUT_ENABLER]
        );
    }

    function _storePegin(
        bytes32 _requestPeginTxid,
        bytes32 _blockHash,
        bytes32 _acceptPeginTxid,
        BtcTxOut memory _acceptPeginTxOutput,
        BtcTxOut memory _enablerOutput
    ) internal {
        // Update the peg in request status to ACCEPTED to avoid processing it again
        streamManager.setPegStatus(_acceptPeginTxid, PegStatus.ACCEPTED);
        StreamPosition memory stream = streamManager.getStreamPosition(_acceptPeginTxid);

        // Fill the reserved slot with accept peg-in transaction details
        streamManager.fillSlot(
            stream,
            _acceptPeginTxOutput.amount,
            _acceptPeginTxid,
            _acceptPeginTxOutput.scriptPubKey,
            _enablerOutput.scriptPubKey
        );

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

        // Check if we need a new packet/committee
        if (stream.slotId == Constants.SLOT_USAGE_THRESHOLD - 1) {
            committeeRegistry.createCommittee(stream.streamId);
        }

        if (stream.slotId >= Constants.SLOT_USAGE_THRESHOLD) {
            if (committeeRegistry.isPendingCommitteeExpired(stream.streamId)) {
                committeeRegistry.createCommittee(stream.streamId);
            }
        }

        // Mint RBTC to the destination address via RbtcBridge
        rbtcBridge.mintRbtc(payable(requestTempInfo.rskDestinationAddress), rbtcAmount);
    }

    /// @notice Gets the stream position information for a given request peg-in transaction id
    /// @dev Looks up the corresponding accept peg-in txid and queries the StreamManager
    /// @param _requestPeginTxid The request peg-in Bitcoin transaction id to look up
    /// @return The stream position information
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
