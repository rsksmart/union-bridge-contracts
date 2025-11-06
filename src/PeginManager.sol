// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {PegManagerBase} from "./PegManagerBase.sol";
import {IPeginManager, RequestPeginTempInfo} from "./interfaces/IPeginManager.sol";
import {ICommitteeRegistry} from "./interfaces/ICommitteeRegistry.sol";
import {Stream, Packet} from "./interfaces/IStreamManager.sol";
import {IBitcoinManager, PrevoutData, BitcoinSignatureData, BtcTxOut} from "./interfaces/IBitcoinManager.sol";
import {BtcTxSPVProof, StreamPosition, PegStatus} from "./interfaces/IPegCommonTypes.sol";
import {BtcHelper} from "./libraries/BtcHelper.sol";
import {Constants} from "./libraries/Constants.sol";

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
    /// @dev This function can only be called once during contract deployment
    function initialize(
        address _initialOwner,
        address payable _bridgeAddress,
        ICommitteeRegistry _committeeRegistry,
        IBitcoinManager _bitcoinManager
    ) public virtual initializer {
        __PegManagerBase_init(_initialOwner, _bridgeAddress, _committeeRegistry, _bitcoinManager);
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

    /// @notice Generates a temporary Bitcoin deposit address for peg-in operations
    /// @param _rootstockDepositAddress The Rootstock address where RBTC will be minted
    /// @param _value The amount in satoshis for determining the appropriate stream
    /// @param _btcReimbursementPubKey The Bitcoin public key for reimbursement transactions
    /// @return bitcoinDepositAddress The generated Bitcoin deposit address
    /// @dev This address is used for the initial peg-in request transaction
    function getTemporaryPeginAddress(address _rootstockDepositAddress, uint64 _value, bytes32 _btcReimbursementPubKey)
        external
        view
        returns (string memory bitcoinDepositAddress, uint64 packetNumber)
    {
        // Get the stream for this value
        Stream memory stream = streamManager.getStream(_value);

        // Get the current packet's committee key
        Packet memory currentPacket = streamManager.getPacket(stream.streamId, stream.peginPacketPointer);
        bytes memory committeeKey = currentPacket.committeePubKey;

        return (
            bitcoinManager.getTemporaryPeginAddress(
                _rootstockDepositAddress, _value, _btcReimbursementPubKey, committeeKey
            ),
            currentPacket.packetNumber
        );
    }

    /// @notice Requests a peg-in operation by providing an SPV proof of the Bitcoin transaction
    /// @param _peginRequestTxSPVProof The SPV proof containing the Bitcoin transaction and merkle proof
    /// @dev This function validates the peg-in request transaction and initiates the peg-in process
    /// @dev The transaction must have at least 2 outputs: one P2TR output and one OP_RETURN output
    /// @dev Emits the PeginRequested event
    /// @dev Only callable when contract is unpaused
    function requestPegin(BtcTxSPVProof calldata _peginRequestTxSPVProof) external nonReentrant whenNotPaused {
        bytes32 requestPeginTxid = _validatePeginRequestProof(_peginRequestTxSPVProof);

        (
            uint64 packetNumber,
            address rskDestinationAddress,
            bytes32 btcReimbursementPubKey,
            Stream memory stream,
            bytes memory committeePubKey
        ) = _extractPeginData(_peginRequestTxSPVProof);

        _validatePeginTransaction(
            _peginRequestTxSPVProof,
            rskDestinationAddress,
            btcReimbursementPubKey,
            committeePubKey,
            stream,
            requestPeginTxid
        );

        // Pre-compute signature data before external calls to follow checks-effects-interactions
        PrevoutData memory prevoutData = PrevoutData({
            value: _peginRequestTxSPVProof.btcTx.outputs[Constants.VOUT_INDEX_TAPTREE].amount,
            scriptPubKey: _peginRequestTxSPVProof.btcTx.outputs[Constants.VOUT_INDEX_TAPTREE].scriptPubKey
        });

        BitcoinSignatureData memory acceptPeginSignatureData = bitcoinManager.getAcceptPeginSignatureHash(
            committeePubKey, btcReimbursementPubKey, requestPeginTxid, prevoutData
        );

        // Store temp info before external calls
        RequestPeginTempInfo memory requestPeginInfo = RequestPeginTempInfo({
            rskDestinationAddress: rskDestinationAddress,
            btcReimbursementPubKey: btcReimbursementPubKey,
            acceptPeginSignatureHash: acceptPeginSignatureData.signatureHash
        });
        peginTempInfo[requestPeginTxid] = requestPeginInfo;

        // Pre-compute committee ID before external calls
        uint128 committeeId = streamManager.getCommitteeId(stream.streamId, packetNumber);

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
            Constants.VOUT_INDEX_TAPTREE,
            streamPos,
            requestPeginInfo,
            prevoutData,
            acceptPeginSignatureData.signatureMessage
        );

        // Final external calls - moved to end to minimize reentrancy attack surface
        // slither-disable-next-line reentrancy-no-eth reentrancy-benign
        signatureManager.initSignatures(acceptPeginSignatureData.txid, committeeId);
        // slither-disable-next-line reentrancy-no-eth reentrancy-benign
        signatureManager.initOperatorTakeTxids(acceptPeginSignatureData.txid, committeeId);
    }

    function _validatePeginRequestProof(BtcTxSPVProof calldata _peginRequestTxSPVProof)
        internal
        view
        returns (bytes32 requestPeginTxid)
    {
        if (_peginRequestTxSPVProof.btcTx.version != Constants.BTC_TX_VERSION) {
            revert InvalidBtcTxVersion(_peginRequestTxSPVProof.btcTx.version, Constants.BTC_TX_VERSION);
        }

        if (_peginRequestTxSPVProof.btcTx.locktime != Constants.LOCKTIME) {
            revert InvalidLocktime(_peginRequestTxSPVProof.btcTx.locktime, Constants.LOCKTIME);
        }

        // Calculate requestPeginTxid from BtcTransaction
        requestPeginTxid = bitcoinManager.getBtcTxid(_peginRequestTxSPVProof.btcTx);
        if (_getStreamPositionByRequestPegin(requestPeginTxid).pegStatus != PegStatus.NOT_REGISTERED) {
            revert PeginAlreadyRequested(requestPeginTxid);
        }

        // Validate transaction has at least 2 outputs
        if (_peginRequestTxSPVProof.btcTx.outputs.length < 2) {
            revert IncorrectOutputsNumber(uint64(_peginRequestTxSPVProof.btcTx.outputs.length), 2);
        }
    }

    function _extractPeginData(BtcTxSPVProof calldata _peginRequestTxSPVProof)
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
        (packetNumber, rskDestinationAddress, btcReimbursementPubKey) =
            bitcoinManager.getPeginOpReturnData(_peginRequestTxSPVProof.btcTx.outputs[Constants.VOUT_INDEX_SPEED_UP]);

        // First transaction is the Pegin P2TR _peginRequestTxSPVProof.btcTx.outputs[0]
        // Get corresponding stream for the amount if non found reverts
        stream = streamManager.getStream(_peginRequestTxSPVProof.btcTx.outputs[Constants.VOUT_INDEX_TAPTREE].amount);

        // getCommitteePubKey reverts if packet does not exist
        committeePubKey = streamManager.getCommitteePubKey(stream.streamId, packetNumber);
    }

    function _validatePeginTransaction(
        BtcTxSPVProof calldata _peginRequestTxSPVProof,
        address rskDestinationAddress,
        bytes32 btcReimbursementPubKey,
        bytes memory committeePubKey,
        Stream memory stream,
        bytes32 requestPeginTxid
    ) internal view {
        // Validates that the Taproot Script has a Key Path for the committeePubKey
        // and has a timelock for btcReimbursementPubKey
        bitcoinManager.validateRequestPeginP2TROutput(
            rskDestinationAddress,
            stream.denomination,
            btcReimbursementPubKey,
            committeePubKey,
            _peginRequestTxSPVProof.btcTx.outputs[Constants.VOUT_INDEX_TAPTREE]
        );

        // Verifies the requestPeginTxid part of the Merkle Root of Tx of a Block
        // and that block is inside Bitcoin Mainchain
        // and has enough confirmations
        _verifyTxConfirmations(
            stream.peginConfirmations,
            requestPeginTxid,
            _peginRequestTxSPVProof.blockHash,
            _peginRequestTxSPVProof.merkleBranchPath,
            _peginRequestTxSPVProof.merkleBranchHashes
        );
    }

    /// @notice Accepts a peg-in operation by providing an SPV proof of the accept peg-in transaction
    /// @param _peginAcceptedTxSPVProof The SPV proof containing the accept peg-in Bitcoin transaction
    /// @dev This function validates the accept peg-in transaction, it must spend the output from the request peg-in transaction
    /// @dev Updates the stream position to ACCEPTED and stores the peg-in transaction in the stream
    /// @dev Emits the PeginAccepted event
    /// @dev Only callable when contract is unpaused
    function acceptPegin(BtcTxSPVProof calldata _peginAcceptedTxSPVProof) external nonReentrant whenNotPaused {
        // The first input consumes the the peg in request utxo
        bytes32 requestPeginTxid = _peginAcceptedTxSPVProof.btcTx.inputs[Constants.VOUT_INDEX_TAPTREE].txId;

        // Validate the peg in request tx exists and the status
        StreamPosition memory streamInfo = _getStreamPositionByRequestPegin(requestPeginTxid);
        if (streamInfo.pegStatus == PegStatus.NOT_REGISTERED) {
            revert PeginNotRequested(requestPeginTxid);
        }
        if (streamInfo.pegStatus != PegStatus.REGISTERED) {
            revert PeginAlreadyAccepted(requestPeginTxid);
        }

        // Calculate acceptPegintxid from BtcTransaction
        bytes32 acceptPegintxid = bitcoinManager.getBtcTxid(_peginAcceptedTxSPVProof.btcTx);

        // Validate the txid is the same calculated at request peg in tx
        if (acceptPegins[requestPeginTxid] != acceptPegintxid) {
            revert InvalidAcceptPeginTxid(acceptPegins[requestPeginTxid], acceptPegintxid);
        }

        // Verify the acceptPegintxid part of the Merkle Root of Tx of a Block
        // and that block is inside Bitcoin Mainchain
        // annd has enough confirmations
        _verifyTxConfirmations(
            streamManager.getStreamById(streamInfo.streamId).peginConfirmations,
            acceptPegintxid,
            _peginAcceptedTxSPVProof.blockHash,
            _peginAcceptedTxSPVProof.merkleBranchPath,
            _peginAcceptedTxSPVProof.merkleBranchHashes
        );

        _storePegin(
            requestPeginTxid,
            _peginAcceptedTxSPVProof.blockHash,
            acceptPegintxid,
            _peginAcceptedTxSPVProof.btcTx.outputs[Constants.VOUT_INDEX_TAPTREE]
        );
    }

    function _storePegin(
        bytes32 _requestPeginTxid,
        bytes32 _blockHash,
        bytes32 _acceptPegintxid,
        BtcTxOut memory _acceptPeginTxOutput
    ) internal {
        // Update the peg in request status to ACCEPTED to avoid processing it again
        streamManager.setPegStatus(_acceptPegintxid, PegStatus.ACCEPTED);
        StreamPosition memory stream = streamManager.getStreamPosition(_acceptPegintxid);

        // Fill the reserved slot with accept peg-in transaction details
        streamManager.fillSlot(stream, _acceptPeginTxOutput.amount, _acceptPegintxid, _acceptPeginTxOutput.scriptPubKey);

        uint256 rbtcAmount = BtcHelper.satoshiToWei(_acceptPeginTxOutput.amount);
        RequestPeginTempInfo storage requestTempInfo = peginTempInfo[_requestPeginTxid];

        // slither-disable-next-line reentrancy-events
        emit PeginAccepted(
            _blockHash,
            _acceptPegintxid,
            _requestPeginTxid,
            Constants.VOUT_INDEX_TAPTREE,
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

        // TODO mint the peg in tokens
        //requestRbtc(rskDestinationAddress, rbtcAmount);
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
