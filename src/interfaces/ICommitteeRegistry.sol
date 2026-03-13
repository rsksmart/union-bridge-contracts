// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {StreamDenomination} from "./IStreamManager.sol";
import {IMemberRegistry, MemberRegistrationKeys, CompactPubKey} from "./IMemberRegistry.sol";
import {SignatureData} from "./ISignatureManager.sol";

/// @dev Amount of bytes32 chunks for communication data
uint8 constant COMMUNICATION_DATA_CHUNKS = 8;

struct CommitteeRegistrySettings {
    /// @notice Timeout in seconds for pending committee formation
    uint256 pendingCommitteeTimeout;
    /// @notice Minimum number of watchtowers required for a committee
    uint256 minCommitteeWatchtowers;
    /// @notice Minimum number of operators required for a committee
    uint256 minCommitteeOperators;
    /// @notice Minimum number of members required for a committee
    uint256 committeeMemberCount;
}

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
    /// @notice Bitcoin take public key of the committee (aggregated from member keys)
    bytes takeAggregatedKey;
    /// @notice Bitcoin dispute public key of the committee (aggregated from member keys)
    bytes disputeAggregatedKey;
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
    /// @notice Take aggregated key provided by the member
    bytes takeAggregatedKey;
    /// @notice Dispute aggregated key provided by the member
    bytes disputeAggregatedKey;
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
    /// @notice Checks if an address is whitelisted
    /// @param _address The address to check
    /// @return True if the address is whitelisted, false otherwise
    function isWhitelisted(address _address) external view returns (bool);

    /// @notice Whitelists an address to enable it to apply to a stream
    /// @dev Only callable by the contract whitelister
    /// @param _address The address to whitelist
    function whitelistAddress(address _address) external;

    /// @notice Whitelists multiple addresses to enable them to apply to a stream
    /// @dev Only callable by the contract whitelister
    /// @param _addresses The addresses to whitelist
    function whitelistAddresses(address[] memory _addresses) external;

    /// @notice Unwhitelists an address to disable it from applying to a stream
    /// @dev Only callable by the contract whitelister
    /// @param _address The address to unwhitelist
    function unwhitelistAddress(address _address) external;

    /// @notice Unwhitelists multiple addresses to disable them from applying to a stream
    /// @dev Only callable by the contract whitelister
    /// @param _addresses The addresses to unwhitelist
    function unwhitelistAddresses(address[] memory _addresses) external;

    /// @notice Applies to participate in a stream with a specific role
    /// @dev Registers public keys, deposits required bond, and provides funding UTXO for the requested role
    /// @param _requestedStream The stream denomination to apply for
    /// @param _requestedRole The role requested in the committee
    /// @param _publicKeys Member public key registration with ECDSA and RSA hash keys
    /// @param _fundingUTXO The Bitcoin UTXO that will be used for committee funding
    function applyToStream(
        StreamDenomination _requestedStream,
        Role _requestedRole,
        MemberRegistrationKeys calldata _publicKeys,
        UTXO calldata _fundingUTXO
    ) external payable;

    /// @notice Unsubscribes from a stream and sets the pre-staked balance as available
    /// @dev Only callable when contract is unpaused
    /// @param _denomination The stream denomination to unsubscribe from
    function unsubscribeFromStream(StreamDenomination _denomination) external;

    /// @notice Gets a committee by its ID
    /// @param _committeeId The committee ID
    /// @return Committee The complete committee information
    function getCommittee(uint128 _committeeId) external view returns (Committee calldata);

    /// @notice Retrieves the committee take aggregated public key for a specific packet
    /// @param _committeeId The committee ID
    /// @return bytes The committee take aggregated public key for this packet (33 bytes compressed format)
    function getCommitteeTakePubKey(uint128 _committeeId) external view returns (bytes memory);

    /// @notice Retrieves the committee dispute aggregated public key for a specific packet
    /// @param _committeeId The committee ID
    /// @return bytes The committee dispute aggregated public key for this packet (33 bytes compressed format)
    function getCommitteeDisputePubKey(uint128 _committeeId) external view returns (bytes memory);

    /// @notice Gets all members of a specific committee
    /// @param _committeeId The committee ID
    /// @return Array of committee members with their roles
    function getCommitteeMembers(uint128 _committeeId) external view returns (CommitteeMember[] memory);

    /// @notice Gets the number of members in a specific committee
    /// @param _committeeId The committee ID
    /// @return The number of committee members (e.g. for validating input-not-revealed tx output count)
    function getCommitteeMembersLength(uint128 _committeeId) external view returns (uint256);

    /// @notice Gets the member registry contract address
    /// @return The member registry contract
    function memberRegistry() external view returns (IMemberRegistry);

    /// @notice Allows a member to deposit their aggregated keys for committee formation
    /// @dev Called by members to provide their take and dispute aggregated keys for a pending committee
    /// @dev Only callable when contract is unpaused
    /// @param _committeeId The ID of the pending committee
    /// @param _takeAggregatedKey The take aggregated public key provided by the member (must be exactly 33 bytes)
    /// @param _disputeAggregatedKey The dispute aggregated public key provided by the member (must be exactly 33 bytes)
    function depositAggregatedKeys(
        uint128 _committeeId,
        bytes memory _takeAggregatedKey,
        bytes memory _disputeAggregatedKey
    ) external;

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
    /// @dev Only callable when contract is unpaused
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

    /// @notice Validates that a member is part of a specific committee; reverts if not
    /// @param _committeeId The committee ID
    /// @param _memberAddress The address of the member to check
    function validateMemberInCommittee(uint128 _committeeId, address _memberAddress) external view;

    /// @notice Sets the Whitelister address
    /// @dev Only callable by the contract owner
    /// @param _newWhitelister The address of the whitelister
    function setWhitelister(address _newWhitelister) external;

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

    /// @notice Demotes an operator to watchtower in a specific active committee
    /// @dev Only callable by the contract owner
    /// @dev Owner-only access is temporary, once slashing is implemented, this function
    ///      will be internal and called directly by the slashing mechanism
    /// @param _committeeId The ID of the active committee
    /// @param _memberAddress The address of the operator to demote
    function demoteOperatorToWatchtower(uint128 _committeeId, address _memberAddress) external;

    /// @notice Gets the operator dispute data (address and dispute public key) for operator-take operations
    /// @dev Rotates through committee operators to distribute take responsibilities
    /// @dev Only operators who have deposited their signatures nonces are eligible for take operations
    /// @param _committeeId The committee ID to get the operator from
    /// @param _signatureData Array of signature data for committee members
    /// @param _missingNonces Number of missing nonces
    /// @return operatorAddress The address of the next available operator for take operations
    /// @return disputePubKey The operator's dispute public key
    /// @return takePubKey The operator's take public key
    /// @dev Reverts with TakeOperatorNotFound if no eligible operator is found
    function selectTakeOperator(uint128 _committeeId, SignatureData[] calldata _signatureData, uint8 _missingNonces)
        external
        returns (address operatorAddress, CompactPubKey memory disputePubKey, CompactPubKey memory takePubKey);

    /// @notice Releases committee members from a packet and handles their staked balance
    /// @dev Called by PegManager to release committee members after packet completion
    /// @dev Only callable by PegManager contract
    /// @dev Members with reApply=true will be re-added as candidates, others get their balance as available
    /// @param _streamId The stream ID for the committee
    /// @param _packetNumber The packet number where the committee was active
    function releaseCommittee(uint64 _streamId, uint64 _packetNumber) external;

    /// @notice Restarts a pending committee if it has expired
    /// @dev Only callable when contract is unpaused
    /// @param _streamId The stream ID to restart the pending committee for
    function restartPendingCommittee(uint64 _streamId) external;

    // ===================== Getters =====================
    /// @notice Gets the committee member count
    /// @return The committee member count
    function committeeMemberCount() external view returns (uint256);

    /// @notice Gets the minimum watchtowers required for a committee
    /// @return The minimum watchtowers required for a committee
    function minCommitteeWatchtowers() external view returns (uint256);

    /// @notice Gets the minimum operators required for a committee
    /// @return The minimum operators required for a committee
    function minCommitteeOperators() external view returns (uint256);

    /// @notice Gets the pending committee timeout
    /// @return The pending committee timeout
    function pendingCommitteeTimeout() external view returns (uint256);

    /// @notice Gets the dispute keys for all committee members
    /// @param _committeeId The committee ID
    /// @return Array of dispute keys for all members
    function getCommitteeDisputeKeys(uint128 _committeeId) external view returns (CompactPubKey[] memory);

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

    /// @notice Event emitted when minimum watchtowers requirement is updated
    /// @param minWatchtowers The new minimum watchtowers requirement
    event CommitteeMinWatchtowersUpdated(uint256 minWatchtowers);

    /// @notice Event emitted when minimum operators requirement is updated
    /// @param minOperators The new minimum operators requirement
    event CommitteeMinOperatorsUpdated(uint256 minOperators);

    /// @notice Event emitted when minimum members requirement is updated
    /// @param minMembers The new minimum members requirement
    event CommitteeMemberCountUpdated(uint256 minMembers);

    /// @notice Event emitted when the whitelister address is updated
    /// @param newWhitelister The new whitelister address
    event WhitelisterUpdated(address indexed newWhitelister);

    /// @notice Event emitted when an address is whitelisted
    /// @param whitelistedAddress The address that is now whitelisted
    event AddressWhitelisted(address indexed whitelistedAddress);

    /// @notice Event emitted when an address is unwhitelisted
    /// @param unwhitelistedAddress The address that is now unwhitelisted
    event AddressUnwhitelisted(address indexed unwhitelistedAddress);

    /// @notice Event emitted when member info is deposited for committee formation
    /// @param committeeId The ID of the pending committee
    /// @param member The member's address
    /// @param takeAggregatedKey The take aggregated key provided by the member
    /// @param disputeAggregatedKey The dispute aggregated key provided by the member
    event MemberInfoDeposited(
        uint128 indexed committeeId, address indexed member, bytes takeAggregatedKey, bytes disputeAggregatedKey
    );

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

    /// @notice Event emitted when members from a packet's committee are released
    /// @param streamId The stream ID for the committee
    /// @param packetNumber The packet number where the committee was active
    event CommitteeMembersReleased(uint64 streamId, uint64 packetNumber);

    /// @notice Event emitted when an operator is demoted to watchtower in a committee
    /// @param committeeId The committee where the demotion occurred
    /// @param memberAddress The address of the demoted member
    event OperatorDemotedToWatchtower(uint128 indexed committeeId, address indexed memberAddress);

    // ===================== Errors =====================
    /// @notice Thrown when a committee is not in pending state
    /// @param committeeId The ID of the committee that is not pending
    error CommitteeIsNotPending(uint128 committeeId);

    /// @notice Thrown when a pending committee is not expired
    /// @param streamId The stream ID
    /// @param createdAt The creation timestamp
    /// @param expireAt The expiration timestamp
    error PendingCommitteeNotExpired(uint64 streamId, uint256 createdAt, uint256 expireAt);

    /// @notice Thrown when non-whitelisted address tries to apply to stream
    /// @param nonWhitelistedAddress The non-whitelisted address
    error NonWhitelistedAddress(address nonWhitelistedAddress);

    /// @notice Thrown when the caller is not the whitelister
    /// @param sender The address of the caller
    error UnauthorizedWhitelister(address sender);

    /// @notice Error thrown when the aggregated key has an invalid length
    /// @param length The actual length provided
    /// @param expected The expected length (33 bytes)
    error InvalidAggregatedKeyLength(uint256 length, uint256 expected);

    /// @notice Error thrown when the aggregated key is all zeros
    error InvalidAggregatedKeyZero();

    /// @notice Error thrown when take and dispute aggregated keys are the same
    error InvalidSameAggregatedKeys();

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

    /// @notice Thrown when a value is zero
    error InvalidZeroValue();

    /// @notice Thrown when minimum members requirement is invalid
    /// @param minMembers The minimum members requirement
    /// @param minCommitteWatchtowers The minimum watchtowers requirement
    /// @param minCommitteOperators The minimum operators requirement
    error InvalidMinMembers(uint256 minMembers, uint256 minCommitteWatchtowers, uint256 minCommitteOperators);

    /// @notice Thrown when committee member count exceeds the maximum allowed
    /// @param maxCommitteeMemberCount The maximum allowed committee member count
    /// @param committeeMemberCount The requested committee member count
    error InvalidMaxMembers(uint256 maxCommitteeMemberCount, uint256 committeeMemberCount);

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

    /// @notice Error when attempting to deposit data in a committee that has already expired
    /// @param committeeId The ID of the committee
    /// @param currentTime Timestamp actual
    /// @param createdAt Timestamp committee creation
    /// @param expireAt Timestamp committee expiration
    error PendingCommitteeExpired(uint128 committeeId, uint256 currentTime, uint256 createdAt, uint256 expireAt);

    /// @notice Thrown when trying to demote from a committee that is still pending
    /// @param committeeId The ID of the pending committee
    error CommitteeIsNotActive(uint128 committeeId);

    /// @notice Thrown when the member is not an operator in the given committee
    /// @param committeeId The committee ID
    /// @param memberAddress The member's address
    error MemberIsNotOperatorInCommittee(uint128 committeeId, address memberAddress);

    /// @notice Thrown when demotion would drop the committee below the minimum operator count
    /// @param committeeId The committee ID
    /// @param currentOperators The current number of operators in the committee
    /// @param minOperators The minimum required
    error DemotionViolatesMinOperators(uint128 committeeId, uint256 currentOperators, uint256 minOperators);

    // --- TESTNET ONLY: Force close committee functionality ---
    // TODO: Remove before mainnet deployment
    /// @notice Forces a discard of a pending committee, and enables the creation of a new committee
    /// @dev Only callable on testnet
    /// @param _streamId The stream ID for the pending committee to discard
    function forceDiscardPendingCommittee_TESTNET(uint64 _streamId) external;

    event PendingCommitteeForceDiscarded(uint64 streamId, uint128 committeeId);
    // --- END TESTNET ONLY ---
}
