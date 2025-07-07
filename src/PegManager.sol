// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {BaseProxy} from "./BaseProxy.sol";
import {ICommitteeRegistry} from "./interfaces/ICommitteeRegistry.sol";
import {ISignatureManager, SignatureData} from "./interfaces/ISignatureManager.sol";
import {PrevoutData, BtcTransaction, BtcTxOut, IBitcoinManager} from "./interfaces/IBitcoinManager.sol";
import {
    BtcTxSPVProof,
    RequestPeginTempInfo,
    PegoutTempInfo,
    StreamPosition,
    PegStatus,
    IPegManager,
    PegManagerSettings
} from "./interfaces/IPegManager.sol";
import {Slot, Stream, Packet, SlotState, IStreamManager} from "./interfaces/IStreamManager.sol";
import {ProofValidator} from "./ProofValidator.sol";
import {BtcHelper} from "./libraries/BtcHelper.sol";
import {BytesHelper} from "./libraries/BytesHelper.sol";
import {Constants} from "./libraries/Constants.sol";
import {BtcScriptParser} from "./libraries/BtcScriptParser.sol";

/// @title PegManager
/// @notice Manages peg-in and peg-out operations between Bitcoin and Rootstock
/// @dev This contract handles the complete lifecycle of Bitcoin peg operations including:
/// - Requesting peg-ins with SPV proofs
/// - Accepting peg-ins with committee signatures
/// - Processing peg-outs and associated committee signatures
/// - Managing temporary Bitcoin deposit addresses
/// - Coordinating with StreamManager for slot allocation
/// - Integrating with CommitteeRegistry for committee management
contract PegManager is IPegManager, BaseProxy, ProofValidator {
    /// @notice Bitcoin manager contract for Bitcoin transaction validation and address generation
    IBitcoinManager public bitcoinManager;

    /// @notice Stream manager contract for managing union bridge streams and slots
    IStreamManager public streamManager;

    /// @notice Committee registry contract for managing committee and members
    ICommitteeRegistry public committeeRegistry;

    /// @notice Signature manager contract for handling multi-signature operations
    ISignatureManager public signatureManager;

    /// @notice Timeout for user take operations
    uint256 public userTakeTimeout;

    /// @notice Timeout for operator take operations
    uint256 public operatorTakeTimeout;

    mapping(bytes32 requestPeginTxHash => bytes32 acceptPeginTxhash) internal peginRequests;

    mapping(bytes32 acceptPeginTxhash => StreamPosition streamPosition) internal streamPosition;

    mapping(bytes32 requestPeginTxHash => RequestPeginTempInfo tempInfo) internal peginTempInfo;

    mapping(bytes32 acceptPeginTxHash => PegoutTempInfo tempInfo) internal pegoutTempInfo;

    mapping(bytes32 pegoutSignatureHash => bytes32 acceptPeginTxHash) internal pegoutToPeginTxHash;

    // Key = keccak256(abi.encodePacked(streamId, packetNumber, slotId))
    mapping(bytes32 key => bytes32 pegoutSignatureHash) internal pegoutSighashes;

    /// @notice Initializes the PegManager contract
    /// @param _initialOwner The initial owner of the contract
    /// @param _bridgeAddress The address of the pow-peg bridge contract
    /// @param _committeeRegistry The committee registry contract address
    /// @param _bitcoinManager The Bitcoin manager contract address
    /// @param _settings The peg manager settings including timeouts
    /// @dev This function can only be called once during contract deployment
    function initialize(
        address _initialOwner,
        address payable _bridgeAddress,
        ICommitteeRegistry _committeeRegistry,
        IBitcoinManager _bitcoinManager,
        PegManagerSettings memory _settings
    ) public virtual initializer {
        // Validate that the bitcoin manager is not zero address
        if (address(_bitcoinManager) == address(0)) {
            revert BitcoinManagerAddressZero();
        }
        bitcoinManager = _bitcoinManager;

        if (address(_committeeRegistry) == address(0)) {
            revert CommitteeRegistryAddressZero();
        }
        committeeRegistry = _committeeRegistry;

        __BaseProxy_init(_initialOwner);
        __ProofValidator_init(_bridgeAddress);

        userTakeTimeout = _settings.userTakeTimeout;
        operatorTakeTimeout = _settings.operatorTakeTimeout;
    }

    /// @notice Sets the stream manager contract address
    /// @param _streamManager The stream manager contract address
    /// @dev Only callable by the contract owner
    function setStreamManager(IStreamManager _streamManager) external onlyOwner {
        if (address(_streamManager) == address(0)) {
            revert StreamManagerAddressZero();
        }
        streamManager = _streamManager;
    }

    /// @notice Sets the signature manager contract address
    /// @param _signatureManager The signature manager contract address
    /// @dev Only callable by the contract owner
    function setSignatureManager(ISignatureManager _signatureManager) external onlyOwner {
        if (address(_signatureManager) == address(0)) {
            revert SignatureManagerAddressZero();
        }
        signatureManager = _signatureManager;
    }

    /// @notice Gets the accept peg-in transaction hash for a given request peg-in transaction hash
    /// @param _requestPeginTxHash The request peg-in transaction hash
    /// @return The accept peg-in transaction hash
    function getPeginRequest(bytes32 _requestPeginTxHash) external view returns (bytes32) {
        return peginRequests[_requestPeginTxHash];
    }

    /// @notice Gets the temporary peg-in information for a given request peg-in transaction hash
    /// @param _btcTxHash The request peg-in transaction hash
    /// @return The temporary peg-in information
    function getRequestPeginTempInfo(bytes32 _btcTxHash) external view returns (RequestPeginTempInfo memory) {
        return peginTempInfo[_btcTxHash];
    }

    /// @notice Gets the temporary peg-out information for a given accept peg-in transaction hash
    /// @param _acceptPeginTxHash The accept peg-in transaction hash
    /// @return The temporary peg-out information
    function getPegoutTempInfo(bytes32 _acceptPeginTxHash) external view returns (PegoutTempInfo memory) {
        return pegoutTempInfo[_acceptPeginTxHash];
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
        returns (string memory bitcoinDepositAddress)
    {
        // Get the stream for this value
        Stream memory stream = streamManager.getStream(_value);

        // Get the current packet's committee key
        Packet memory currentPacket = streamManager.getPacket(stream.streamId, stream.peginPacketPointer);
        bytes32 committeeKey = currentPacket.committeePubKey;

        return bitcoinManager.getTemporaryPeginAddress(
            _rootstockDepositAddress, _value, _btcReimbursementPubKey, committeeKey
        );
    }

    /// @notice Requests a peg-in operation by providing an SPV proof of the Bitcoin transaction
    /// @param _peginRequestTxSPVProof The SPV proof containing the Bitcoin transaction and merkle proof
    /// @dev This function validates the peg-in request transaction and initiates the peg-in process
    /// @dev The transaction must have at least 2 outputs: one P2TR output and one OP_RETURN output
    /// @dev Emits the PeginRequested event
    function requestPegin(BtcTxSPVProof calldata _peginRequestTxSPVProof) external {
        if (_peginRequestTxSPVProof.btcTx.version != Constants.BTC_TX_VERSION) {
            revert InvalidBtcTxVersion(_peginRequestTxSPVProof.btcTx.version, Constants.BTC_TX_VERSION);
        }
        if (_peginRequestTxSPVProof.btcTx.locktime != Constants.LOCKTIME) {
            revert InvalidLocktime(_peginRequestTxSPVProof.btcTx.locktime, Constants.LOCKTIME);
        }
        // Calculate requestPeginTxHash from BtcTransaction
        bytes32 requestPeginTxHash = bitcoinManager.getBtcTxHash(_peginRequestTxSPVProof.btcTx);
        if (_getStreamPosition(requestPeginTxHash).pegStatus != PegStatus.NOT_REGISTERED) {
            revert PeginAlreadyRequested(requestPeginTxHash);
        }
        // Validate transaction has at least 2 outputs
        if (_peginRequestTxSPVProof.btcTx.outputs.length < 2) {
            revert IncorrectOutputsNumber(uint64(_peginRequestTxSPVProof.btcTx.outputs.length), 2);
        }
        // Second transaction should be OP_RETURN with data
        (uint64 packetNumber, address rskDestinationAddress, bytes32 btcReimbursementPubKey) =
            bitcoinManager.getPeginOpReturnData(_peginRequestTxSPVProof.btcTx.outputs[Constants.VOUT_INDEX_SPEED_UP]);
        // First transaction is the Pegin P2TR _peginRequestTxSPVProof.btcTx.outputs[0]
        // Get corresponding stream for the amount if non found reverts
        Stream memory stream =
            streamManager.getStream(_peginRequestTxSPVProof.btcTx.outputs[Constants.VOUT_INDEX_TAPTREE].amount);

        // getCommitteePubKey reverts if packet does not exist
        bytes32 committeePubKey = streamManager.getCommitteePubKey(stream.streamId, packetNumber);

        // Validates that the Taproot Script has a Key Path for the committeePubKey
        // and has a timelock for btcReimbursementPubKey
        bitcoinManager.validateRequestPeginP2TROutput(
            rskDestinationAddress,
            stream.denomination,
            btcReimbursementPubKey,
            committeePubKey,
            _peginRequestTxSPVProof.btcTx.outputs[Constants.VOUT_INDEX_TAPTREE]
        );

        // Verify the requestPeginTxHash part of the Merkle Root of Tx of a Block
        // and that block is inside Bitcoin Mainchain
        // and has enough confirmations
        _verifyTxConfirmations(
            stream.peginConfirmations,
            requestPeginTxHash,
            _peginRequestTxSPVProof.blockHash,
            _peginRequestTxSPVProof.merkleBranchPath,
            _peginRequestTxSPVProof.merkleBranchHashes
        );

        _initAcceptPegin(
            committeePubKey,
            btcReimbursementPubKey,
            requestPeginTxHash,
            rskDestinationAddress,
            PrevoutData({
                value: _peginRequestTxSPVProof.btcTx.outputs[Constants.VOUT_INDEX_TAPTREE].amount,
                scriptPubKey: _peginRequestTxSPVProof.btcTx.outputs[Constants.VOUT_INDEX_TAPTREE].scriptPubKey
            }),
            stream.streamId,
            packetNumber
        );
    }

    function _initAcceptPegin(
        bytes32 _committeePubKey,
        bytes32 _userXOnlyPubKey,
        bytes32 _registerPeginTxHash,
        address _rskDestinationAddress,
        PrevoutData memory _prevoutData,
        uint64 _streamId,
        uint64 _packetNumber
    ) internal {
        // Compute the Bitcoin accept peg-in transaction signature hash
        (bytes32 acceptPeginTxHash, bytes32 acceptPeginSignatureHash, bytes memory acceptPeginSignatureMessage) =
        bitcoinManager.getAcceptPeginSignatureHash(
            _committeePubKey, _userXOnlyPubKey, _registerPeginTxHash, _prevoutData
        );

        // Store peginRequest requestPeginTxHash to avoid processing it again
        peginRequests[_registerPeginTxHash] = acceptPeginTxHash;
        streamPosition[acceptPeginTxHash] = StreamPosition({
            streamId: _streamId,
            packetNumber: _packetNumber,
            slotId: 0,
            pegStatus: PegStatus.REGISTERED
        });

        // Store pegin info needed for acceptPegin
        RequestPeginTempInfo memory requestPeginInfo = RequestPeginTempInfo({
            rskDestinationAddress: _rskDestinationAddress,
            btcReimbursementPubKey: _userXOnlyPubKey,
            acceptPeginSignatureHash: acceptPeginSignatureHash
        });
        peginTempInfo[_registerPeginTxHash] = requestPeginInfo;

        // Initialize the signatures needed for a given aggregated key
        uint256 committeeId = streamManager.getCommitteeId(_streamId, _packetNumber);
        emit PeginRequested(
            streamManager.getCommitteeId(_streamId, _packetNumber),
            _registerPeginTxHash,
            acceptPeginTxHash,
            Constants.VOUT_INDEX_TAPTREE, // vout is the first output, is the P2TR
            _streamId,
            _packetNumber,
            requestPeginInfo,
            _prevoutData,
            acceptPeginSignatureMessage
        );

        signatureManager.initSignatures(acceptPeginSignatureHash, committeeId);
        signatureManager.initOperatorTakeTxHashes(acceptPeginTxHash, committeeId);
    }

    /// @notice Accepts a peg-in operation by providing an SPV proof of the accept peg-in transaction
    /// @param _peginAcceptedTxSPVProof The SPV proof containing the accept peg-in Bitcoin transaction
    /// @dev This function validates the accept peg-in transaction, it must spend the output from the request peg-in transaction
    /// @dev Updates the stream position to ACCEPTED and stores the peg-in transaction in the stream
    /// @dev Emits the PeginAccepted event
    function acceptPegin(BtcTxSPVProof calldata _peginAcceptedTxSPVProof) external {
        // The first input consumes the the peg in request utxo
        bytes32 requestPeginTxHash = _peginAcceptedTxSPVProof.btcTx.inputs[Constants.VOUT_INDEX_TAPTREE].txId;

        // Validate the peg in request tx exists and the status
        StreamPosition memory streamInfo = _getStreamPosition(requestPeginTxHash);
        if (streamInfo.pegStatus == PegStatus.NOT_REGISTERED) {
            revert PeginNotRequested(requestPeginTxHash);
        }
        if (streamInfo.pegStatus != PegStatus.REGISTERED) {
            revert PeginAlreadyAccepted(requestPeginTxHash);
        }

        // Calculate acceptPegintxHash from BtcTransaction
        bytes32 acceptPegintxHash = bitcoinManager.getBtcTxHash(_peginAcceptedTxSPVProof.btcTx);

        // Validate the txhash is the same calculated at request peg in tx
        if (peginRequests[requestPeginTxHash] != acceptPegintxHash) {
            revert InvalidAcceptPeginTxHash(peginRequests[requestPeginTxHash], acceptPegintxHash);
        }

        // Verify the acceptPegintxHash part of the Merkle Root of Tx of a Block
        // and that block is inside Bitcoin Mainchain
        // annd has enough confirmations
        _verifyTxConfirmations(
            streamManager.getStreamById(streamInfo.streamId).peginConfirmations,
            acceptPegintxHash,
            _peginAcceptedTxSPVProof.blockHash,
            _peginAcceptedTxSPVProof.merkleBranchPath,
            _peginAcceptedTxSPVProof.merkleBranchHashes
        );

        _storePegin(
            requestPeginTxHash,
            streamInfo,
            _peginAcceptedTxSPVProof.blockHash,
            acceptPegintxHash,
            _peginAcceptedTxSPVProof.btcTx.outputs[Constants.VOUT_INDEX_TAPTREE]
        );
    }

    function _storePegin(
        bytes32 _requestPeginTxHash,
        StreamPosition memory streamInfo,
        bytes32 _blockHash,
        bytes32 _acceptPegintxHash,
        BtcTxOut memory _acceptPeginTxOutput
    ) internal {
        StreamPosition storage stream = streamPosition[_acceptPegintxHash];
        // Update the peg in request status to ACCEPTED to avoid processing it again
        stream.pegStatus = PegStatus.ACCEPTED;

        // Store Tx in peginSlot as Filled
        stream.slotId = streamManager.fillAcceptPeginTx(
            streamInfo.streamId,
            streamInfo.packetNumber,
            _acceptPeginTxOutput.amount,
            _acceptPegintxHash,
            _acceptPeginTxOutput.scriptPubKey
        );

        uint256 rbtcAmount = BtcHelper.satoshiToWei(_acceptPeginTxOutput.amount);
        RequestPeginTempInfo storage requestTempInfo = peginTempInfo[_requestPeginTxHash];

        // slither-disable-next-line reentrancy-events
        emit PeginAccepted(
            _blockHash,
            _acceptPegintxHash,
            _requestPeginTxHash,
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

    function _validatePegoutRequest(bytes calldata _userPubKey, uint256 amountInWei) internal pure {
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
    function tryPegout(bytes calldata _userPubKey) external payable {
        _validatePegoutRequest(_userPubKey, msg.value);

        Stream memory stream = streamManager.getStream(uint64(BtcHelper.weiToSatoshi(msg.value)));
        // slither-disable-next-line reentrancy-benign
        (Slot memory slot, uint64 packetNumber) = streamManager.lockSlot(stream.streamId);

        // Compute the Bitcoin peg-out signature hash
        (bytes32 pegoutSignatureHash, bytes memory pegoutSignatureMessage) = bitcoinManager.getPegoutSignatureHash(
            _userPubKey,
            slot.acceptPeginTx,
            PrevoutData({value: slot.acceptPeginAmount, scriptPubKey: slot.scriptPubKey})
        );

        uint256 committeeId =
            _storePegoutAndInitSignatures(pegoutSignatureHash, stream.streamId, packetNumber, slot.slotId);

        pegoutTempInfo[slot.acceptPeginTx] = PegoutTempInfo({
            userPubKey: _userPubKey,
            createdAt: block.timestamp,
            operatorTakeUpdatedAt: 0,
            takeOperator: address(0),
            committeeId: committeeId
        });
        streamPosition[slot.acceptPeginTx].pegStatus = PegStatus.USER_TAKE;

        // Store the pegout to pegin tx hash mapping
        pegoutToPeginTxHash[pegoutSignatureHash] = slot.acceptPeginTx;

        // TODO: return RBTC to the RSK Legacy Bridge following https://github.com/rsksmart/RSKIPs/pull/502

        // slither-disable-next-line reentrancy-events
        emit PegoutRequested(
            _userPubKey,
            committeeId,
            pegoutSignatureHash,
            pegoutSignatureMessage,
            stream.streamId,
            packetNumber,
            slot.slotId,
            stream.denomination,
            // NOTE: not in a function because of stack too deep
            // this hash is the pegout id
            keccak256(
                abi.encode(
                    stream.streamId,
                    packetNumber,
                    slot.slotId,
                    msg.sender,
                    bytes32(bridge.getBtcBlockchainBlockHashAtDepth(1))
                )
            )
        );
    }

    /// @notice Register a peg-out transaction from Bitcoin
    /// @param _pegoutTxSPVProof The BTC SPV proof of the peg-out transaction
    /// @dev This function validates the peg-out transaction and marks the slot as COMPLETED
    /// @dev The transaction must spend the accept peg-in output and pay to the user's address
    /// @dev Emits the PegoutRegistered event
    function registerUserTake(BtcTxSPVProof calldata _pegoutTxSPVProof) external {
        // Get the accept peg-in tx hash from the first input (this is what gets spent)
        bytes32 acceptPeginTxHash = _pegoutTxSPVProof.btcTx.inputs[0].txId;
        uint32 vout = _pegoutTxSPVProof.btcTx.inputs[0].vout;

        // get the stream data for this pegout
        StreamPosition memory streamInfo = streamPosition[acceptPeginTxHash];

        if (streamInfo.pegStatus == PegStatus.NOT_REGISTERED) {
            revert PeginNotRequested(acceptPeginTxHash);
        }

        // Validate that the vout is correct
        if (vout != Constants.VOUT_INDEX_TAPTREE) {
            revert IncorrectVout(vout, Constants.VOUT_INDEX_TAPTREE);
        }

        // Calculate the transaction hash for verification
        bytes32 requestPegoutTxHash = bitcoinManager.getBtcTxHash(_pegoutTxSPVProof.btcTx);

        // Get the stream to check confirmations
        Stream memory stream = streamManager.getStreamById(streamInfo.streamId);

        // Verify the requestPegoutTxHash is part of the Merkle Root and has enough confirmations
        _verifyTxConfirmations(
            stream.pegoutConfirmations,
            requestPegoutTxHash,
            _pegoutTxSPVProof.blockHash,
            _pegoutTxSPVProof.merkleBranchPath,
            _pegoutTxSPVProof.merkleBranchHashes
        );

        // Validate that the first output is a P2WPKH paying the user
        bytes memory userPubKey = pegoutTempInfo[acceptPeginTxHash].userPubKey;
        bitcoinManager.validatePegoutUserOutput(_pegoutTxSPVProof.btcTx.outputs[0], userPubKey);

        // update the peg status to COMPLETED
        streamPosition[acceptPeginTxHash].pegStatus = PegStatus.COMPLETED;

        emit PegoutRegistered(
            _pegoutTxSPVProof.blockHash,
            requestPegoutTxHash,
            acceptPeginTxHash,
            streamInfo.streamId,
            streamInfo.packetNumber,
            streamInfo.slotId
        );

        if (streamInfo.slotId == Constants.SLOTS_PER_PACKET - 1) {
            // if the last slot of the packet was paid, we can release the members of the committee
            emit PacketClosed(streamInfo.streamId, streamInfo.packetNumber);
            committeeRegistry.releaseCommittee(streamInfo.streamId, streamInfo.packetNumber);
        }

        // Update slot status
        streamManager.completeSlot(
            streamInfo.streamId, streamInfo.packetNumber, streamInfo.slotId, acceptPeginTxHash, requestPegoutTxHash
        );
    }

    /// @notice Gets the peg-out signature hash for a specific stream, packet, and slot
    /// @param streamId The stream identifier
    /// @param packetNumber The packet number within the stream
    /// @param slotId The slot identifier within the packet
    /// @return The peg-out signature hash
    function getPegoutSignatureHash(uint64 streamId, uint64 packetNumber, uint64 slotId)
        external
        view
        returns (bytes32)
    {
        bytes32 key = keccak256(abi.encodePacked(streamId, packetNumber, slotId));
        return pegoutSighashes[key];
    }

    /// @notice Gets the stream position information for a given Bitcoin Pegin request transaction hash
    /// @param _btcTxHash The Bitcoin transaction hash
    /// @return The stream position information
    function getStreamPosition(bytes32 _btcTxHash) external view returns (StreamPosition memory) {
        return _getStreamPosition(_btcTxHash);
    }

    function _getStreamPosition(bytes32 _btcTxHash) internal view returns (StreamPosition memory) {
        return streamPosition[peginRequests[_btcTxHash]];
    }

    function _storePegoutAndInitSignatures(
        bytes32 _pegoutSignatureHash,
        uint64 _streamId,
        uint64 _packetNumber,
        uint64 _slotId
    ) internal returns (uint256) {
        // Store the peg-out transaction hash on-chain and initialize the signatures
        bytes32 key = keccak256(abi.encodePacked(_streamId, _packetNumber, _slotId));
        pegoutSighashes[key] = _pegoutSignatureHash;

        // Get the committee key
        uint256 committeeId = streamManager.getCommitteeId(_streamId, _packetNumber);

        // Initialize the signatures for each member
        signatureManager.initSignatures(_pegoutSignatureHash, committeeId);

        return committeeId;
    }

    /// @notice Triggers the operator take process for a peg-out when not all committee members sign within timeout
    /// @dev This function can be called after a User Take expiration or after an Operator Take expiration
    /// @dev Each case has its own timeout and before triggering the operator take (after a User Take expiration)
    /// @dev signatures should be checked to see if the User Take was already signed
    /// @dev Partial signatures are used to skip those operators that have not signed the User Take
    /// @dev Emits OperatorTakeTriggered event upon successful triggering
    /// @param _pegoutSignatureHash The signature hash of the peg-out request
    function triggerOperatorTake(bytes32 _pegoutSignatureHash) external {
        // This method trigger the operator take for a pegout.
        // It could be after a User Take expiration or after an Operator Take expiration.
        // Each case has its own timeout and before triggering the operator take (after a User Take expiration)
        // signatures should be checked to see if the User Take was already signed.
        // Partial signatures are used to skip those operators that has not signed the User Take.

        bytes32 acceptPeginTxHash = pegoutToPeginTxHash[_pegoutSignatureHash];
        if (acceptPeginTxHash == bytes32(0)) {
            revert PegoutSignatureHashNotFound(_pegoutSignatureHash);
        }

        PegoutTempInfo storage pegoutInfo = pegoutTempInfo[acceptPeginTxHash];
        StreamPosition storage streamInfo = streamPosition[acceptPeginTxHash];
        bool advanceSlot = false;
        uint256 operatorTakeUpdatedAt = pegoutInfo.operatorTakeUpdatedAt;
        pegoutInfo.operatorTakeUpdatedAt = block.timestamp;

        if (streamInfo.pegStatus == PegStatus.USER_TAKE) {
            // slither-disable-next-line unused-return
            (uint8 missingSignatures,,) = signatureManager.getSignaturesStatus(_pegoutSignatureHash);
            if (missingSignatures == 0) {
                revert UserTakeAlreadySigned(_pegoutSignatureHash);
            }

            // slither-disable-next-line timestamp
            if (block.timestamp <= pegoutInfo.createdAt + userTakeTimeout) {
                revert UserTakeTimeoutNotExpired(pegoutInfo.createdAt, pegoutInfo.createdAt + userTakeTimeout);
            }

            streamInfo.pegStatus = PegStatus.OPERATOR_TAKE;
            advanceSlot = true;
        } else if (streamInfo.pegStatus == PegStatus.OPERATOR_TAKE) {
            // slither-disable-next-line timestamp
            if (block.timestamp <= operatorTakeUpdatedAt + operatorTakeTimeout) {
                revert OperatorTakeTimeoutNotExpired(operatorTakeUpdatedAt, operatorTakeUpdatedAt + operatorTakeTimeout);
            }
        } else {
            revert InvalidPegStatus(streamInfo.pegStatus);
        }

        SignatureData[] memory signatureData = signatureManager.getPartialSignatures(_pegoutSignatureHash);
        pegoutInfo.takeOperator = committeeRegistry.getOperatorTakeAddress(pegoutInfo.committeeId, signatureData);

        // slither-disable-next-line reentrancy-events
        emit OperatorTakeTriggered(
            _pegoutSignatureHash,
            pegoutInfo.committeeId,
            acceptPeginTxHash,
            pegoutInfo.takeOperator,
            pegoutInfo.userPubKey,
            pegoutInfo.createdAt,
            block.timestamp,
            block.timestamp + operatorTakeTimeout
        );

        if (advanceSlot) {
            streamManager.advanceSlot(streamInfo.streamId, streamInfo.packetNumber, streamInfo.slotId);
        }
    }

    /// @notice Deposits an operator take proof for a peg-out transaction
    /// @param _pegoutTxSPVProof The BTC SPV proof of the operator take peg-out transaction
    /// @dev Validates the SPV proof and marks the slot as paid when operator takes over
    /// @dev Only callable when the peg status is OPERATOR_TAKE
    /// @dev Emits PegoutRegistered event upon successful deposit
    function registerOperatorTake(BtcTxSPVProof calldata _pegoutTxSPVProof) external {
        // Get the accept peg-in tx hash from the first input (this is what gets spent)
        bytes32 acceptPeginTxHash = _pegoutTxSPVProof.btcTx.inputs[0].txId;
        uint32 vout = _pegoutTxSPVProof.btcTx.inputs[0].vout;

        // get the stream data for this pegout
        StreamPosition memory streamInfo = streamPosition[acceptPeginTxHash];

        if (streamInfo.pegStatus == PegStatus.NOT_REGISTERED) {
            revert PeginNotRequested(acceptPeginTxHash);
        }

        if (streamInfo.pegStatus != PegStatus.OPERATOR_TAKE) {
            revert InvalidPegStatus(streamInfo.pegStatus);
        }

        // Validate that the vout is correct
        if (vout != Constants.VOUT_INDEX_TAPTREE) {
            revert IncorrectVout(vout, Constants.VOUT_INDEX_TAPTREE);
        }

        PegoutTempInfo memory pegoutInfo = pegoutTempInfo[acceptPeginTxHash];
        // slither-disable-next-line timestamp
        if (pegoutInfo.takeOperator != msg.sender) {
            revert OperatorTakeAddressNotMatch(pegoutInfo.takeOperator, msg.sender);
        }

        // Calculate the transaction hash for verification
        bytes32 txHash = bitcoinManager.getBtcTxHash(_pegoutTxSPVProof.btcTx);

        // Get the stream to check confirmations
        Stream memory stream = streamManager.getStreamById(streamInfo.streamId);

        // Verify the txHash is part of the Merkle Root and has enough confirmations
        _verifyTxConfirmations(
            stream.pegoutConfirmations,
            txHash,
            _pegoutTxSPVProof.blockHash,
            _pegoutTxSPVProof.merkleBranchPath,
            _pegoutTxSPVProof.merkleBranchHashes
        );

        // Validate that the first output is a P2WPKH paying the member
        bytes32 operatorPubKey = committeeRegistry.getMemberTakePubKey(pegoutInfo.takeOperator);
        bitcoinManager.validatePegoutMemberOutput(_pegoutTxSPVProof.btcTx.outputs[0], operatorPubKey);

        // update the peg status to COMPLETED
        streamPosition[acceptPeginTxHash].pegStatus = PegStatus.COMPLETED;

        emit PegoutRegistered(
            _pegoutTxSPVProof.blockHash,
            txHash,
            acceptPeginTxHash,
            streamInfo.streamId,
            streamInfo.packetNumber,
            streamInfo.slotId
        );

        // Update slot status
        streamManager.completeSlot(
            streamInfo.streamId, streamInfo.packetNumber, streamInfo.slotId, acceptPeginTxHash, txHash
        );
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
}
