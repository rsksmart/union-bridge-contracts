// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {PrevoutData} from "./IBitcoinManager.sol";
import {IPausable} from "./IPausable.sol";
import {BtcTxSPVProof, StreamPosition, PegStatus} from "./IPegCommonTypes.sol";

/// @notice Temporary information stored during peg-in request processing
/// @dev Contains data needed for the accept peg-in phase
struct RequestPeginTempInfo {
    /// @notice The RSK address that will receive the RBTC
    address rskDestinationAddress;
    /// @notice The user's Bitcoin public key for reimbursement (x-coordinate only)
    bytes32 btcReimbursementPubKey;
    /// @notice The signature hash that committee members need to sign
    bytes32 acceptPeginSignatureHash;
    /// @notice The block number of the request peg-in transaction
    int256 btcBlockNumber;
    /// @notice The transaction id of the user reimbursement transaction
    bytes32 userReimbursementTxid;
    /// @notice The transaction id of the rejected peg-in transaction
    bytes32 rejectPeginTxid;
}

/// @title IPeginManager
/// @notice Interface for managing peg-in operations
interface IPeginManager is IPausable {
    // ===================== Peg-in Request =====================

    /// @notice Generates request peg-in data including temporary Bitcoin address and member dispute keys
    /// @dev Creates a Taproot address with committee and user reimbursment paths for secure peg-in
    /// @dev Returns an array of dispute keys (covenant keys) for each committee member in order
    /// @param _rootstockDepositAddress The RSK address that will receive the RBTC
    /// @param _value The amount in satoshis to peg in (must match stream denomination)
    /// @param _btcReimbursementPubKey The user's Bitcoin public key (x-coordinate only, 32 bytes)
    /// @return temporaryPeginAddress The generated temporary Bitcoin address for deposit
    /// @return packetNumber The packet number for this peg-in request
    /// @return memberDisputeKeys Array of dispute keys (covenant keys) for each committee member in order
    function getRequestPeginData(address _rootstockDepositAddress, uint64 _value, bytes32 _btcReimbursementPubKey)
        external
        view
        returns (
            string memory temporaryPeginAddress,
            uint64 packetNumber,
            bytes32[] memory memberDisputeKeys,
            uint64 availableSlots
        );

    /// @notice Retrieves the stream position information for a given request peg-in transaction id
    /// @dev Looks up the corresponding accept peg-in txid and queries the StreamManager
    /// @param requestPeginTxid The request peg-in Bitcoin transaction id to look up
    /// @return The stream position containing stream, packet, slot, and status information
    function getStreamPositionByRequestPegin(bytes32 requestPeginTxid) external view returns (StreamPosition memory);

    /// @notice Registers a peg-in request transaction from Bitcoin
    /// @dev Validates the SPV proof and initiates the peg-in process
    /// @dev Emits PeginRequested event upon successful registration
    /// @param _requestPeginTxSPVProof The BTC SPV proof of the peg-in request transaction
    function requestPegin(BtcTxSPVProof calldata _requestPeginTxSPVProof) external;

    /// @notice Gets the accept peg-in transaction id for a given request transaction id
    /// @param _btcTxid The Bitcoin transaction id of the peg-in request
    /// @return The accept peg-in transaction id
    function getAcceptPegin(bytes32 _btcTxid) external view returns (bytes32);

    /// @notice Gets temporary information stored during peg-in request processing
    /// @param btcTxid The Bitcoin transaction id of the peg-in request
    /// @return The temporary information needed for the accept phase
    function getRequestPeginTempInfo(bytes32 btcTxid) external view returns (RequestPeginTempInfo memory);

    // ===================== Accept Peg-in Request =====================

    /// @notice Accepts and registers a Bitcoin peg-in transaction to the committee account
    /// @dev Validates the SPV proof and completes the peg-in process
    /// @dev Emits PeginAccepted event upon successful acceptance
    /// @param _peginAcceptedTxSPVProof The BTC SPV proof of the accept peg-in transaction
    function acceptPegin(BtcTxSPVProof calldata _peginAcceptedTxSPVProof) external;

    // ===================== Reject Peg-in Request =====================

    /// @notice Registers a user reimbursement transaction from Bitcoin
    /// @dev Validates the SPV proof and completes the user reimbursement process
    /// @dev Emits UserReimbursementRegistered event upon successful registration
    /// @dev Slot state is set to BLOCKED
    /// @param _userReimbursementTxSPVProof The BTC SPV proof of the user reimbursement transaction
    /// @param _reimbursementPeginVin The input index of the reimbursement peg-in transaction
    function userReimbursement(BtcTxSPVProof calldata _userReimbursementTxSPVProof, uint32 _reimbursementPeginVin)
        external;

    /// @notice Registers a reject peg-in transaction from Bitcoin
    /// @dev Validates the SPV proof and registers the reject peg-in transaction
    /// @dev Emits RejectPeginRegistered event upon successful registration
    /// @dev Slot state is set to BLOCKED
    /// @param _rejectPeginTxSPVProof The BTC SPV proof of the reject peg-in transaction
    function rejectPegin(BtcTxSPVProof calldata _rejectPeginTxSPVProof) external;

    // ===================== Events =====================

    /// @notice Event emitted when a peg-in request is successfully registered
    /// @param committeeId The ID of the committee responsible for this peg-in
    /// @param requestPeginTxid The hash of the peg-in request transaction
    /// @param acceptPeginTxid The hash of the accept peg-in transaction
    /// @param streamPosition The struct with the position information (stream, packet, slot, status)
    /// @param requestPeginInfo Temporary information needed for the accept phase
    /// @param acceptPeginSignatureMessage The signature message for committee signing
    event PeginRequested(
        uint128 indexed committeeId,
        bytes32 indexed requestPeginTxid,
        bytes32 indexed acceptPeginTxid,
        StreamPosition streamPosition,
        RequestPeginTempInfo requestPeginInfo,
        bytes acceptPeginSignatureMessage
    );

    /// @notice Event emitted when a peg-in is successfully accepted
    /// @param blockHash The Bitcoin block hash containing the accept transaction
    /// @param acceptPeginTxid The hash of the accept peg-in transaction
    /// @param requestPeginTxid The hash of the original peg-in request transaction
    /// @param vout The output index of the transaction
    /// @param streamPosition The final position of funds in the stream system
    /// @param speedUpPubKey The public key for speed-up transactions
    /// @param rskDestinationAddress The RSK address that received the RBTC
    /// @param rbtcAmount The amount of RBTC minted
    /// @param utxoScriptPubKey The script pubkey of the UTXO
    event PeginAccepted(
        bytes32 indexed blockHash,
        bytes32 indexed acceptPeginTxid,
        bytes32 indexed requestPeginTxid,
        uint64 vout,
        StreamPosition streamPosition,
        bytes32 speedUpPubKey,
        address rskDestinationAddress,
        uint256 rbtcAmount,
        bytes utxoScriptPubKey
    );

    /// @notice Event emitted when a packet is closed in the stream
    /// @param streamId The ID of the stream where the packet was closed
    /// @param packetNumber The number of the packet that was closed
    /// @dev Indicates that all slots in the packet have been processed and pegged out
    /// @dev This event is used to track the lifecycle of packets in the stream
    event PacketClosed(uint64 indexed streamId, uint64 indexed packetNumber);

    /// @notice Event emitted when a user reimbursement is successfully registered
    /// @param userReimbursementTxid The hash of the user reimbursement btc transaction
    /// @param requestPeginTxid The hash of the request peg-in btc transaction
    /// @param streamInfo The stream position information where the user reimbursement was registered
    event UserReimbursementRegistered(
        bytes32 indexed userReimbursementTxid, bytes32 indexed requestPeginTxid, StreamPosition streamInfo
    );

    /// @notice Event emitted when a reject peg-in is successfully registered
    /// @param rejectPeginTxid The hash of the reject peg-in btc transaction
    /// @param requestPeginTxid The hash of the request peg-in btc transaction
    /// @param streamInfo The stream position information where the reject peg-in was registered
    event RejectPeginRegistered(
        bytes32 indexed rejectPeginTxid, bytes32 indexed requestPeginTxid, StreamPosition streamInfo
    );

    // ===================== Errors =====================

    /// @notice Thrown when a peg-in has already been requested for the given transaction
    /// @param btcTxid The Bitcoin transaction id that was already requested
    error PeginAlreadyRequested(bytes32 btcTxid);

    /// @notice Thrown when trying to process a peg-in that hasn't been requested
    /// @param btcTxid The Bitcoin transaction id that wasn't requested
    error PeginNotRequested(bytes32 btcTxid);

    /// @notice Thrown when the accept peg-in transaction id doesn't match the expected value
    /// @param expected The expected transaction id
    /// @param actual The actual transaction id received
    error InvalidAcceptPeginTxid(bytes32 expected, bytes32 actual);

    /// @notice Thrown when a peg-in has already been accepted
    /// @param btcTxid The Bitcoin transaction id that was already accepted
    error PeginAlreadyAccepted(bytes32 btcTxid);

    /// @notice Thrown when the number of outputs doesn't match the expected count
    /// @param actual The actual number of outputs
    /// @param expected The expected number of outputs
    error IncorrectOutputsNumber(uint256 actual, uint256 expected);

    /// @notice Thrown when the transaction locktime doesn't match the expected value
    /// @param actual The actual locktime value
    /// @param expected The expected locktime value
    error InvalidLocktime(uint256 actual, uint256 expected);

    /// @notice Thrown when the Bitcoin transaction version doesn't match the expected value
    /// @param actual The actual version value
    /// @param expected The expected version value
    error InvalidBtcTxVersion(uint256 actual, uint256 expected);

    /// @notice Thrown when the input amount exceeds the locking cap of the pow-peg bridge
    /// @param value The input amount that exceeded the locking cap
    /// @param lockingCap The locking cap of the pow-peg bridge
    error BridgeExceededLockingCap(uint256 value, uint256 lockingCap);

    /// @notice Thrown when the peg-in status is not valid for the current operation
    /// @param btcTxid The Bitcoin transaction id that was being registered
    /// @param expected The expected peg status
    /// @param actual The actual peg status
    error InvalidPegStatus(bytes32 btcTxid, PegStatus actual, PegStatus expected);

    /// @notice Thrown when the output index (vout) doesn't match the expected value
    /// @param actual The actual vout value
    /// @param expected The expected vout value
    error IncorrectVout(uint32 actual, uint32 expected);

    /// @notice Thrown when the user reimbursement transaction id is the same as the accept peg-in txid
    /// @param userReimbursementTxid The user reimbursement transaction id that is the same as the accept peg-in txid
    error InvalidUserReimbursementTx(bytes32 userReimbursementTxid);

    /// @notice Thrown when the user reimbursement transaction is mined before the timelock period
    /// @param blocksElapsedSinceRequestPegin The number of blocks elapsed since the request peg-in transaction
    /// @param timelockBlocks The timelock period in blocks
    error UserReimbursementBeforeTimelock(int256 blocksElapsedSinceRequestPegin, uint256 timelockBlocks);
}
