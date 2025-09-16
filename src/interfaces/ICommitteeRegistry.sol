// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {StreamDenomination, IStreamManager} from "./IStreamManager.sol";
import {IPegManager} from "./IPegManager.sol";
import {SignatureData} from "./ISignatureManager.sol";
import {IMemberRegistry} from "./IMemberRegistry.sol";

/// @dev Amount of bytes32 chunks for communication data
uint8 constant COMMUNICATION_DATA_CHUNKS = 8;

/// @dev Amount of bytes32 chunks for DER-encoded RSA public key
uint8 constant RSA_PUBLIC_KEY_CHUNKS = 10;

/// @notice Represents a Bitcoin UTXO used for committee member funding
struct UTXO {
    /// @notice The Bitcoin transaction ID containing the UTXO
    bytes32 txid;
    /// @notice The output index within the transaction (as uint32)
    uint32 outputIndex;
    /// @notice The amount of the UTXO in satoshis (as uint64)
    uint64 amount;
}

/// @notice Represents the different roles a committee member can have
/// @dev Each role has specific responsibilities and requirements in the committee
enum Role {
    /// @notice No role assigned
    NONE,
    /// @notice Operator role - responsible for executing peg out operations
    OPERATOR,
    /// @notice Watchtower role - responsible for monitoring and dispute resolution
    WATCHTOWER,
    /// @notice This must always be the last element since it represents the total count of enum elements
    /// @dev Used for validation and iteration over the enum values
    LENGTH
}

/// @notice Represents the status of a pending committee formation
/// @dev Used to track the success or failure reasons of committee creation
enum PendingCommitteeStatus {
    /// @notice Committee formation was successful
    SUCCESS,
    /// @notice Not enough members applied for the committee
    NOT_ENOUGH_MEMBERS,
    /// @notice Not enough operators applied for the committee
    NOT_ENOUGH_OPERATORS,
    /// @notice Not enough watchtowers applied for the committee
    NOT_ENOUGH_WATCHTOWERS,
    /// @notice This must always be the last element since it represents the total count of enum elements
    /// @dev Used for validation and iteration over the enum values
    LENGTH
}

/// @notice Represents the balance and application staking information for a member
/// @dev Tracks available balance, applications, and staked amounts across packets
struct Balance {
    /// @notice Available balance that can be withdrawn
    uint256 available;
    /// @notice Array of application data for different streams
    ApplicationData[] applications;
    /// @notice Mapping of staked amounts for packets where the member is part of a committee
    /// @dev Each element is a mapping from packet number to staked amount
    mapping(uint64 packetNumber => uint256 amount)[] staked;
}

/// @notice Represents application data for a member's role request
/// @dev Contains the requested role, pre-staked amount, and funding UTXO
struct ApplicationData {
    /// @notice The role requested by the member
    Role requestedRole;
    /// @notice Amount pre-staked for this application
    uint256 preStaked;
    /// @notice Whether the member wants to reapply for the committee once a packet is over
    bool reApply;
    /// @notice The Bitcoin UTXO used for funding this application
    UTXO fundingUTXO;
}

/// @notice Represents the different types of public keys a member can register
/// @dev Each key type serves a specific purpose in the committee operations
enum PublicKeyType {
    /// @notice Public key used for take operations (normal peg-out)
    TAKE,
    /// @notice Public key used for covenant operations (dispute resolution)
    COVENANT,
    /// @notice Public key used for communication between members
    COMMUNICATION,
    /// @notice This must always be the last element since it represents the total count of enum elements
    /// @dev Used for validation and iteration over the enum values
    LENGTH
}

/// @notice Represents the data needed for ECDSA public key registration
/// @dev Includes the public key coordinates and ECDSA signature for verification
struct ECDSAPublicKey {
    /// @notice X-coordinate of the public key
    bytes32 publicKeyX;
    /// @notice Y-coordinate of the public key
    bytes32 publicKeyY;
    /// @notice Recovery parameter for ECDSA signature
    uint8 v;
    /// @notice R component of ECDSA signature
    bytes32 r;
    /// @notice S component of ECDSA signature
    bytes32 s;
}

/// @notice Represents RSA public key for communication
/// @dev Contains DER-encoded RSA public key
/// @dev We use a fixed bytes32 array for gas efficiency
struct RSAPublicKey {
    /// @notice DER-encoded RSA public key stored as bytes32 chunks
    bytes32[RSA_PUBLIC_KEY_CHUNKS] rsaPublicKey;
}

/// @notice Member public key registration structure
/// @dev Contains mixed key types for registration
struct MemberRegistrationKeys {
    /// @notice TAKE public key (ECDSA) - fully validated
    ECDSAPublicKey takeKey;
    /// @notice COVENANT public key (ECDSA) - no validation
    ECDSAPublicKey covenantKey;
    /// @notice COMMUNICATION public key (RSA) - RSA validation
    RSAPublicKey communicationKey;
}

/// @notice Member public keys structure for members
/// @dev Contains different key types for different purposes
struct MemberKeys {
    /// @notice TAKE public key (ECDSA)
    bytes32 takePubKey;
    /// @notice COVENANT public key (ECDSA)
    bytes32 covenantPubKey;
    /// @notice COMMUNICATION public key (RSA)
    RSAPublicKey communicationPubKey;
}

/// @notice Represents a committee member with their keys, roles, and balance
/// @dev Contains all information needed to manage a member's participation
struct Member {
    /// @notice Member public keys for different purposes
    /// @dev Contains TAKE (ECDSA), COVENANT (ECDSA), and COMMUNICATION (RSA) keys
    MemberKeys publicKeys;
    /// @notice Balance and staking information for the member
    Balance balance;
    /// @notice Additional data stored as key-value pairs
    mapping(string key => string value) data;
}

/// @notice Represents a member within a specific committee
/// @dev Contains the member's address and assigned role in the committee
struct CommitteeMember {
    /// @notice The member's address
    address memberAddress;
    /// @notice The role assigned to this member in the committee
    Role role;
}

/// @notice Represents a complete committee with aggregated key and members
/// @dev Contains all information needed for committee operations
struct Committee {
    /// @notice Bitcoin public key of the committee (aggregated from member keys)
    bytes aggregatedKey;
    /// @notice Array of committee members with their roles
    CommitteeMember[] members;
    /// @notice Address of the committee leader
    address leaderAddress;
    /// @notice Index of the operator take address
    uint256 operatorTakeIndex;
    /// @notice Timestamp when the pending committee was created
    uint256 createdAt;
    /// @notice Number of members that have not provided their data yet
    uint16 missingData;
    /// @notice Number of members that have not deposited their communication data yet
    uint16 missingCommunicationData;
    /// @notice Whether the committee is pending formation
    bool isPending;
    /// @notice The stream ID this committee is associated with
    uint64 streamId;
    /// @notice the funding UTXOs provided by the members
    UTXO[] fundingUTXOs;
}

/// @notice Represents pending data for a member in committee formation
/// @dev Contains the aggregated key provided by the member and committee status
struct PendingCommitteeData {
    /// @notice Aggregated key provided by the member
    bytes aggregatedKey;
    /// @notice Whether the member is included in the committee
    bool inCommittee;
    /// @notice Array of encrypted Communication Data
    /// @dev IP and Port encrypted for each member in the same order as they appear in the pending committee
    CommunicationData[] communicationData;
}

struct CommunicationData {
    /// @notice The encrypted communication data (IP and Port) for the member
    bytes32[COMMUNICATION_DATA_CHUNKS] data;
}

/// @notice Interface for managing committee registration and formation in the union bridge
/// @dev This interface provides functions for member registration, committee formation,
/// @dev and balance management for the committee system
interface ICommitteeRegistry {
    /// @notice Applies to participate in a stream with a specific role
    /// @dev Registers public keys, deposits required bond, and provides funding UTXO for the requested role
    /// @param _requestedStream The stream denomination to apply for
    /// @param _requestedRole The role requested in the committee
    /// @param _publicKeys Member public key registration with ECDSA and RSA keys
    /// @param _fundingUTXO The Bitcoin UTXO that will be used for committee funding
    function applyToStream(
        StreamDenomination _requestedStream,
        Role _requestedRole,
        MemberRegistrationKeys calldata _publicKeys,
        UTXO calldata _fundingUTXO
    ) external payable;

    /// @notice Unsubscribes from a stream and set as available balance the pre-staked balance
    /// @param _stream The stream denomination to unsubscribe from
    function unsubscribeFromStream(StreamDenomination _stream) external;

    /// @notice Gets a committee by its ID
    /// @param _committeeId The committee ID
    /// @return Committee The complete committee information
    function getCommittee(uint128 _committeeId) external view returns (Committee calldata);

    /// @notice Gets all members of a specific committee
    /// @param _committeeId The committee ID
    /// @return Array of committee members with their roles
    function getCommitteeMembers(uint128 _committeeId) external view returns (CommitteeMember[] memory);

    /// @notice Gets the member registry contract address
    /// @return The member registry contract
    function memberRegistry() external view returns (IMemberRegistry);

    /// @notice Allows a member to deposit information  formation
    /// @dev Called by members to provide their aggregated key for a pending committee
    /// @param _committeeId The ID of the pending committee
    /// @param _aggregatedKey The aggregated public key provided by the member (must be exactly 33 bytes)
    function depositAggregatedKey(uint128 _committeeId, bytes memory _aggregatedKey) external;

    /// @notice Triggers the creation of a new committee for a stream if the timeout has expired
    /// @dev This function is called when the slot usage threshold is reached
    /// @param _streamId The stream ID to create a new committee for
    function createCommittee(uint64 _streamId) external;

    /// @notice Checks if there is a pending committee for the stream and it's expired
    /// @param _streamId The stream ID to check for a pending committee
    /// @return True if the pending committee exists and is expired
    function isPendingCommitteeExpired(uint64 _streamId) external view returns (bool);

    /// @notice Returns the pending committee for the stream
    /// @dev This function will revert if  there is no pending committee or if it's expired
    /// @param _streamId The stream ID to get the pending committee for
    /// @return Committee The pending committee (contains createdAt and missingData fields)
    function getPendingCommittee(uint64 _streamId) external view returns (Committee memory);

    /// @notice Returns the committee ID for a pending committee in the given stream
    /// @param _streamId The stream ID to get the pending committee ID for
    /// @return committeeId The committee ID of the pending committee
    function getPendingCommitteeId(uint64 _streamId) external view returns (uint128 committeeId);

    /// @notice Returns the number of members that have not deposited their communication data yet
    /// @param _committeeId The committee ID to check for missing communication data
    /// @return missingCommunicationData The number of members that have not deposited their communication data yet
    function getMissingCommunicationDataCount(uint128 _committeeId)
        external
        view
        returns (uint16 missingCommunicationData);

    /// @notice Deposits encrypted communication data (IP and Port) for a member in a pending committee
    /// @dev This function is called by members to provide their encrypted communication data
    /// @param _committeeId The ID of the pending committee
    /// @param _communicationData Array of encrypted communication data (IP and Port) for the member
    function depositCommunicationData(uint128 _committeeId, CommunicationData[] memory _communicationData) external;

    /// @notice Gets the encrypted communication data for one member in a committee
    /// @dev This function returns the encrypted communication data (IP and Port) deposited for a particular member
    /// @param _committeeId The committee ID for the committee
    /// @param _memberAddress The address of the member we are requesting data for
    /// @return communicationData encrypted communication data (IP and Port) from the committee members
    /// @dev The order of the data corresponds to the order of members in the committee
    function getMemberCommunicationData(uint128 _committeeId, address _memberAddress)
        external
        view
        returns (CommunicationData[] memory communicationData);

    /// @notice Sets the Peg Manager contract address
    /// @dev Only callable by the contract owner
    /// @param _pegManager The address of the Peg Manager contract
    function setPegManager(IPegManager _pegManager) external;

    /// @notice Sets the Stream Manager contract address
    /// @dev Only callable by the contract owner
    /// @param _streamManager The address of the Stream Manager contract
    function setStreamManager(IStreamManager _streamManager) external;

    /// @notice Sets the pending committee timeout
    /// @dev Only callable by the contract owner
    /// @param _timeout The timeout in seconds for the pending committee
    function setPendingCommitteeTimeout(uint256 _timeout) external;

    /// @notice Sets the minimum watchtowers required for a committee
    /// @dev Only callable by the contract owner
    /// @param _minWatchtowers The minimum watchtowers required for a committee
    function setCommitteeMinWatchtowers(uint256 _minWatchtowers) external;

    /// @notice Sets the minimum operators required for a committee
    /// @dev Only callable by the contract owner
    /// @param _minOperators The minimum operators required for a committee
    function setCommitteeMinOperators(uint256 _minOperators) external;

    /// @notice Sets the exact number of members required for a committee
    /// @dev Only callable by the contract owner
    /// @param _committeeMemberCount The exact number of members required for a committee
    function setCommitteeMemberCount(uint256 _committeeMemberCount) external;

    /// @notice Gets the operator take address for a specific committee
    /// @param committeeId The ID of the committee
    /// @param signatureData The signature data for the committee members
    /// @return The operator take address
    function getOperatorTakeAddress(uint128 committeeId, SignatureData[] calldata signatureData)
        external
        returns (address);

    /// @notice Release the committee members from a packet (return or reapply staked money)
    function releaseCommittee(uint64 _streamId, uint64 _packetNumber) external;

    // ===================== Events =====================
    /// @notice Event emitted when a new committee is created
    /// @param committeeId The ID of the newly created committee
    /// @param _committee The committee information
    event NewCommittee(uint128 indexed committeeId, Committee _committee);

    /// @notice Event emitted when a new pending committee is created
    /// @param committeeId The stream ID for the pending committee
    /// @param _committee The pending committee information
    event NewPendingCommittee(uint128 indexed committeeId, Committee _committee);

    /// @notice Event emitted when pending committee timeout is updated
    /// @param timeout The new timeout value
    event PendingCommitteeTimeoutUpdated(uint256 timeout);

    /// @notice Event emitted when stream manager address is updated
    /// @param streamManager The new stream manager address
    event StreamManagerUpdated(address streamManager);

    /// @notice Event emitted when peg manager address is updated
    /// @param pegManager The new peg manager address
    event PegManagerUpdated(address pegManager);

    /// @notice Event emitted when minimum watchtowers requirement is updated
    /// @param minWatchtowers The new minimum watchtowers requirement
    event CommitteeMinWatchtowersUpdated(uint256 minWatchtowers);

    /// @notice Event emitted when minimum operators requirement is updated
    /// @param minOperators The new minimum operators requirement
    event CommitteeMinOperatorsUpdated(uint256 minOperators);

    /// @notice Event emitted when minimum members requirement is updated
    /// @param minMembers The new minimum members requirement
    event CommitteeMemberCountUpdated(uint256 minMembers);

    /// @notice Event emitted when member info is deposited for committee formation
    /// @param committeeId The ID of the pending committee
    /// @param member The member's address
    /// @param aggregatedKey The aggregated key provided by the member
    event MemberInfoDeposited(uint128 indexed committeeId, address indexed member, bytes aggregatedKey);

    /// @notice Event emitted when no honest operators remain in a committee
    /// @param committeeId The ID of the committee with no honest operators
    event NoRemainingHonestOperators(uint128 committeeId);

    /// @notice Event emitted when a member has deposited their communication data
    /// @param _committeeId The ID of the committee for which the member deposited data
    /// @param member The address of the member who deposited the data
    /// @param communicationData The encrypted communication data deposited by the member
    /// @dev The communication data are encrypted IP's and Port's for each member in the committee
    event MemberCommunicationDataDeposited(
        uint128 indexed _committeeId, address indexed member, CommunicationData[] communicationData
    );

    /// @notice Event emitted when all committee members have deposited their communication data
    /// @param _committeeId The ID of the committee for which all communication data is ready
    event AllCommunicationDataReady(uint128 indexed _committeeId);

    /// @notice Thrown when a committee is not in pending state
    /// @param committeeId The ID of the committee that is not pending
    error CommitteeIsNotPending(uint128 committeeId);

    /// @notice Thrown when a pending committee is not expired
    /// @param streamId The stream ID
    /// @param createdAt The creation timestamp
    /// @param expireAt The expiration timestamp
    error PendingCommitteeNotExpired(uint64 streamId, uint256 createdAt, uint256 expireAt);

    /// @notice Error thrown when the aggregated key has an invalid length
    /// @param length The actual length provided
    /// @param expected The expected length (33 bytes)
    error InvalidAggregatedKeyLength(uint256 length, uint256 expected);

    /// @notice Error thrown when the aggregated key is all zeros
    error InvalidAggregatedKeyZero();

    /// @notice Thrown when a member is not in the committee
    /// @param committeeId The committee ID
    /// @param memberAddress The member's address
    error MemberNotInCommittee(uint128 committeeId, address memberAddress);

    /// @notice Thrown when member info is already deposited
    /// @param committeeId The committee ID
    /// @param memberAddress The member's address
    error MemberInfoAlreadyDeposited(uint128 committeeId, address memberAddress);

    /// @notice Thrown when a committee is not found
    /// @param committeeId The committee ID
    error CommitteeNotFound(uint128 committeeId);

    /// @notice Thrown when an account is not authorized
    /// @param account The unauthorized account
    error UnauthorizedAccount(address account);

    /// @notice Thrown when an address is zero
    error InvalidZeroAddress();

    /// @notice Thrown when a value is zero
    error InvalidZeroValue();

    /// @notice Thrown when minimum members requirement is invalid
    /// @param minMembers The minimum members requirement
    /// @param minCommitteWatchtowers The minimum watchtowers requirement
    /// @param minCommitteOperators The minimum operators requirement
    error InvalidMinMembers(uint256 minMembers, uint256 minCommitteWatchtowers, uint256 minCommitteOperators);

    /// @notice Thrown when minimum operators requirement is invalid
    /// @param minMembers The minimum members requirement
    /// @param minCommitteWatchtowers The minimum watchtowers requirement
    /// @param minCommitteOperators The minimum operators requirement
    error InvalidMinOperators(uint256 minMembers, uint256 minCommitteWatchtowers, uint256 minCommitteOperators);

    /// @notice Thrown when minimum watchtowers requirement is invalid
    /// @param minMembers The minimum members requirement
    /// @param minCommitteWatchtowers The minimum watchtowers requirement
    /// @param minCommitteOperators The minimum operators requirement
    error InvalidMinWatchtowers(uint256 minMembers, uint256 minCommitteWatchtowers, uint256 minCommitteOperators);

    /// @notice Thrown when a member is already in a pending committee
    /// @param memberAddress The member's address
    /// @param denomination The stream denomination
    error MemberIsInPendingCommittee(address memberAddress, StreamDenomination denomination);

    /// @notice Thrown when no eligible operator is found for take operations
    /// @param committeeId The ID of the committee where no operator was found
    error TakeOperatorNotFound(uint128 committeeId);

    /// @notice Thrown when the number of submitted communication data entries does not match the committee size
    /// @param providedLength The actual length of the submitted communication data array
    /// @param expectedLength The expected number of entries (i.e., committee size)
    error InvalidCommunicationDataLength(uint256 providedLength, uint256 expectedLength);

    /// @notice Thrown when a member submits an empty communication data entry for another member
    /// @param index The index of the communication data entry
    /// @param communicationData The invalid communication data submitted
    error InvalidZeroCommunicationData(uint256 index, CommunicationData communicationData);

    /// @notice Thrown when a member submits non-zero communication data for their own slot
    /// @param index The index in the array corresponding to the submitting member
    /// @param communicationData The non-zero data submitted in the member's own slot
    error InvalidNonZeroCommunicationData(uint256 index, CommunicationData communicationData);

    /// @notice Thrown when a member attempts to deposit communication data more than once
    /// @param committeeId The ID of the committee
    /// @param memberAddress The address of the member attempting a second deposit
    /// @param communicationDataLenght The number of communication data entries already stored
    error MemberAlreadyDepositedCommunicationData(
        uint128 committeeId, address memberAddress, uint256 communicationDataLenght
    );
}
