// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {BaseProxy} from "./BaseProxy.sol";
import {Pausable} from "./Pausable.sol";
import {ICommitteeRegistry} from "./interfaces/ICommitteeRegistry.sol";
import {IMemberRegistry} from "./interfaces/IMemberRegistry.sol";
import {ISignatureManager, SignatureData} from "./interfaces/ISignatureManager.sol";
import {PrevoutData, BtcTxOut, IBitcoinManager, BitcoinSignatureData} from "./interfaces/IBitcoinManager.sol";
import {
    BtcTxSPVProof,
    RequestPeginTempInfo,
    PegoutTempInfo,
    StreamPosition,
    PegStatus,
    IPegManager,
    PegManagerSettings
} from "./interfaces/IPegManager.sol";
import {Slot, Stream, Packet, IStreamManager} from "./interfaces/IStreamManager.sol";
import {ProofValidator} from "./ProofValidator.sol";
import {BtcHelper} from "./libraries/BtcHelper.sol";
import {Constants} from "./libraries/Constants.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

/// @title PegManager
/// @notice Manages peg-in and peg-out operations between Bitcoin and Rootstock
/// @dev This contract handles the complete lifecycle of Bitcoin peg operations including:
/// - Requesting peg-ins with SPV proofs
/// - Accepting peg-ins with committee signatures
/// - Processing peg-outs and associated committee signatures
/// - Managing temporary Bitcoin deposit addresses
/// - Coordinating with StreamManager for slot allocation
/// - Integrating with CommitteeRegistry for committee management
contract PegManager is IPegManager, BaseProxy, ProofValidator, ReentrancyGuardUpgradeable, Pausable {
    /// @notice Bitcoin manager contract for Bitcoin transaction validation and address generation
    IBitcoinManager public bitcoinManager;

    /// @notice Stream manager contract for managing union bridge streams and slots
    IStreamManager public streamManager;

    /// @notice Committee registry contract for managing committee and members
    ICommitteeRegistry public committeeRegistry;

    /// @notice Member registry contract for managing member data
    IMemberRegistry public memberRegistry;

    /// @notice Signature manager contract for handling multi-signature operations
    ISignatureManager public signatureManager;

    /// @notice Timeout for user take operations
    uint256 public userTakeTimeout;

    /// @notice Timeout for operator take operations
    uint256 public operatorTakeTimeout;

    mapping(bytes32 requestPeginTxid => bytes32 acceptPeginTxid) internal acceptPegins;

    mapping(bytes32 acceptPeginTxid => StreamPosition streamPosition) internal streamPosition;

    mapping(bytes32 requestPeginTxid => RequestPeginTempInfo tempInfo) internal peginTempInfo;

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
        __ReentrancyGuard_init();

        __Pauser_init();
        pauser = _initialOwner;

        userTakeTimeout = _settings.userTakeTimeout;
        operatorTakeTimeout = _settings.operatorTakeTimeout;
    }

    /// @notice Pauses the contract and the committee registry
    function _pause() internal override {
        super._pause();
        committeeRegistry.pause();
    }

    /// @notice Unpauses the contract and the committee registry
    function _unpause() internal override {
        super._unpause();
        committeeRegistry.unpause();
    }

    /// @notice Sets the stream manager contract address
    /// @param _streamManager The stream manager contract address
    /// @dev Only callable by the contract owner
    function setStreamManager(IStreamManager _streamManager) external onlyOwner {
        if (address(_streamManager) == address(0)) {
            revert StreamManagerAddressZero();
        }
        streamManager = _streamManager;
        emit StreamManagerUpdated(_streamManager);
    }

    /// @notice Sets the signature manager contract address
    /// @param _signatureManager The signature manager contract address
    /// @dev Only callable by the contract owner
    function setSignatureManager(ISignatureManager _signatureManager) external onlyOwner {
        if (address(_signatureManager) == address(0)) {
            revert SignatureManagerAddressZero();
        }
        signatureManager = _signatureManager;
        emit SignatureManagerUpdated(_signatureManager);
    }

    /// @notice Sets the member registry contract address
    /// @param _memberRegistry The member registry contract address
    /// @dev Only callable by the contract owner
    function setMemberRegistry(IMemberRegistry _memberRegistry) external onlyOwner {
        if (address(_memberRegistry) == address(0)) {
            revert MemberRegistryAddressZero();
        }
        memberRegistry = _memberRegistry;
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

    /// @notice Gets the temporary peg-out information for a given accept peg-in transaction id
    /// @param _acceptPeginTxid The accept peg-in transaction id
    /// @return The temporary peg-out information
    function getPegoutTempInfo(bytes32 _acceptPeginTxid) external view returns (PegoutTempInfo memory) {
        return pegoutTempInfo[_acceptPeginTxid];
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

        streamPosition[acceptPeginSignatureData.txid] = streamPos;

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
        if (_getStreamPosition(requestPeginTxid).pegStatus != PegStatus.NOT_REGISTERED) {
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
        StreamPosition memory streamInfo = _getStreamPosition(requestPeginTxid);
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
        StreamPosition storage stream = streamPosition[_acceptPegintxid];
        // Update the peg in request status to ACCEPTED to avoid processing it again
        stream.pegStatus = PegStatus.ACCEPTED;

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
    /// @dev Only callable when contract is unpaused
    function tryPegout(bytes calldata _userPubKey) external payable nonReentrant whenNotPaused {
        _validatePegoutRequest(_userPubKey, msg.value);

        Stream memory stream = streamManager.getStream(uint64(BtcHelper.weiToSatoshi(msg.value)));
        // slither-disable-next-line reentrancy-benign
        (Slot memory slot, uint64 packetNumber) = streamManager.lockSlot(stream.streamId);

        // Compute the Bitcoin peg-out signature hash
        BitcoinSignatureData memory pegoutSignatureData = bitcoinManager.getPegoutTxData(
            _userPubKey,
            slot.acceptPeginTx,
            PrevoutData({value: slot.acceptPeginAmount, scriptPubKey: slot.scriptPubKey})
        );

        uint128 committeeId =
            _storePegoutAndInitSignatures(pegoutSignatureData.txid, stream.streamId, packetNumber, slot.slotId);

        pegoutTempInfo[slot.acceptPeginTx] = PegoutTempInfo({
            userPubKey: _userPubKey,
            createdAt: block.timestamp,
            operatorTakeUpdatedAt: 0,
            committeeId: committeeId,
            takeOperatorAddress: address(0),
            takeOperatorPubKey: bytes32(0)
        });
        streamPosition[slot.acceptPeginTx].pegStatus = PegStatus.USER_TAKE;

        // Store the pegout to pegin tx id mapping
        pegoutToPeginTxid[pegoutSignatureData.txid] = slot.acceptPeginTx;

        // TODO: return RBTC to the RSK Legacy Bridge following https://github.com/rsksmart/RSKIPs/pull/502

        // Compute pegout ID
        bytes32 pegoutId = keccak256(
            abi.encode(
                stream.streamId,
                packetNumber,
                slot.slotId,
                _msgSender(),
                bytes32(bridge.getBtcBlockchainBlockHashAtDepth(1))
            )
        );

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
    }

    /// @notice Register a peg-out transaction from Bitcoin
    /// @param _pegoutTxSPVProof The BTC SPV proof of the peg-out transaction
    /// @dev This function validates the peg-out transaction and marks the slot as COMPLETED
    /// @dev The transaction must spend the accept peg-in output and pay to the user's address
    /// @dev Emits the PegoutRegistered event
    /// @dev Only callable when contract is unpaused
    function registerUserTake(BtcTxSPVProof calldata _pegoutTxSPVProof) external nonReentrant whenNotPaused {
        // Get the accept peg-in tx id from the first input (this is what gets spent)
        bytes32 acceptPeginTxid = _pegoutTxSPVProof.btcTx.inputs[0].txId;
        uint32 vout = _pegoutTxSPVProof.btcTx.inputs[0].vout;

        // get the stream data for this pegout
        StreamPosition memory streamInfo = streamPosition[acceptPeginTxid];

        if (streamInfo.pegStatus == PegStatus.NOT_REGISTERED) {
            revert PeginNotRequested(acceptPeginTxid);
        }

        // Validate that the vout is correct
        if (vout != Constants.VOUT_INDEX_TAPTREE) {
            revert IncorrectVout(vout, Constants.VOUT_INDEX_TAPTREE);
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
        bytes memory userPubKey = pegoutTempInfo[acceptPeginTxid].userPubKey;
        bitcoinManager.validatePegoutUserOutput(_pegoutTxSPVProof.btcTx.outputs[0], userPubKey);

        // update the peg status to COMPLETED
        streamPosition[acceptPeginTxid].pegStatus = PegStatus.COMPLETED;

        emit PegoutRegistered(
            _pegoutTxSPVProof.blockHash,
            requestPegoutTxid,
            acceptPeginTxid,
            pegoutTempInfo[acceptPeginTxid].committeeId,
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
            streamInfo.streamId, streamInfo.packetNumber, streamInfo.slotId, acceptPeginTxid, requestPegoutTxid
        );
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

    /// @notice Gets the stream position information for a given Bitcoin Pegin request transaction id
    /// @param _acceptPeginTxid The accept peg-in Bitcoin transaction id
    /// @return The stream position information
    function getStreamPosition(bytes32 _acceptPeginTxid) external view returns (StreamPosition memory) {
        return _getStreamPosition(_acceptPeginTxid);
    }

    function _getStreamPosition(bytes32 _acceptPeginTxid) internal view returns (StreamPosition memory) {
        return streamPosition[acceptPegins[_acceptPeginTxid]];
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
        StreamPosition storage streamInfo = streamPosition[acceptPeginTxid];
        bool advanceSlot = false;
        uint256 operatorTakeUpdatedAt = pegoutInfo.operatorTakeUpdatedAt;
        pegoutInfo.operatorTakeUpdatedAt = block.timestamp;

        if (streamInfo.pegStatus == PegStatus.USER_TAKE) {
            // slither-disable-next-line unused-return
            (uint8 missingSignatures,,) = signatureManager.getSignaturesStatus(_pegoutTxid);
            if (missingSignatures == 0) {
                revert UserTakeAlreadySigned(_pegoutTxid);
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

        SignatureData[] memory signatureData = signatureManager.getPartialSignatures(_pegoutTxid);

        // slither-disable-next-line reentrancy-no-eth reentrancy-benign
        address takeOperatorAddress = committeeRegistry.getOperatorTakeAddress(pegoutInfo.committeeId, signatureData);
        bytes32 takeOperatorPubKey = memberRegistry.getMemberTakePubKey(takeOperatorAddress);

        // Update state variables after external calls
        pegoutInfo.takeOperatorAddress = takeOperatorAddress;
        pegoutInfo.takeOperatorPubKey = takeOperatorPubKey;

        // slither-disable-next-line reentrancy-events
        emit OperatorTakeTriggered(
            _pegoutTxid, pegoutInfo, streamInfo, block.timestamp, block.timestamp + operatorTakeTimeout
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
    /// @dev Only callable when contract is unpaused
    function registerOperatorTake(BtcTxSPVProof calldata _pegoutTxSPVProof) external whenNotPaused {
        // Get the accept peg-in tx id from the first input (this is what gets spent)
        bytes32 acceptPeginTxid = _pegoutTxSPVProof.btcTx.inputs[0].txId;
        uint32 vout = _pegoutTxSPVProof.btcTx.inputs[0].vout;

        // get the stream data for this pegout
        StreamPosition memory streamInfo = streamPosition[acceptPeginTxid];

        if (streamInfo.pegStatus == PegStatus.NOT_REGISTERED) {
            revert PeginNotRequested(acceptPeginTxid);
        }

        if (streamInfo.pegStatus != PegStatus.OPERATOR_TAKE) {
            revert InvalidPegStatus(streamInfo.pegStatus);
        }

        // Validate that the vout is correct
        if (vout != Constants.VOUT_INDEX_TAPTREE) {
            revert IncorrectVout(vout, Constants.VOUT_INDEX_TAPTREE);
        }

        PegoutTempInfo memory pegoutInfo = pegoutTempInfo[acceptPeginTxid];
        address sender = _msgSender();
        // slither-disable-next-line timestamp
        if (pegoutInfo.takeOperatorAddress != sender) {
            revert OperatorTakeAddressNotMatch(pegoutInfo.takeOperatorAddress, sender);
        }

        // Calculate the transaction id for verification
        bytes32 txid = bitcoinManager.getBtcTxid(_pegoutTxSPVProof.btcTx);

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

        // Validate that the first output is a P2WPKH paying the member
        bytes32 takeOperatorPubKey = memberRegistry.getMemberTakePubKey(pegoutInfo.takeOperatorAddress);
        bitcoinManager.validatePegoutMemberOutput(_pegoutTxSPVProof.btcTx.outputs[0], takeOperatorPubKey);

        // update the peg status to COMPLETED
        streamPosition[acceptPeginTxid].pegStatus = PegStatus.COMPLETED;

        emit PegoutRegistered(
            _pegoutTxSPVProof.blockHash,
            txid,
            acceptPeginTxid,
            pegoutInfo.committeeId,
            streamInfo.streamId,
            streamInfo.packetNumber,
            streamInfo.slotId
        );

        // Update slot status
        streamManager.completeSlot(
            streamInfo.streamId, streamInfo.packetNumber, streamInfo.slotId, acceptPeginTxid, txid
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
