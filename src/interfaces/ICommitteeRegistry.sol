// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {StreamDenomination, IStreamManager} from "./IStreamManager.sol";
import {IPegManager} from "./IPegManager.sol";
import {SignatureData} from "./ISignatureManager.sol";

/// @notice Represents the different roles a committee member can have
/// @dev Each role has specific responsibilities and requirements in the committee
enum Role {
    /// @notice No role assigned
    NONE,
    /// @notice Operator role - responsible for executing peg out operations
    OPERATOR,
    /// @notice Watchtower role - responsible for monitoring and dispute resolution
    WATCHTOWER
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
    NOT_ENOUGH_WATCHTOWERS
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
/// @dev Contains the requested role and pre-staked amount
struct ApplicationData {
    /// @notice The role requested by the member
    Role requestedRole;
    /// @notice Amount pre-staked for this application
    uint256 preStaked;
    bool reApply;
}

/// @notice Represents the different types of public keys a member can register
/// @dev Each key type serves a specific purpose in the committee operations
enum PublicKeyIndex {
    /// @notice Public key used for take operations (normal peg-out)
    TAKE,
    /// @notice Public key used for covenant operations (dispute resolution)
    COVENANT,
    /// @notice Public key used for communication between members
    COMMUNICATION
}

/// @dev Constant representing the total number of public key types
uint8 constant PUBLIC_KEYS_INDEX_LENGTH = 3; // uint8(PublicKeyIndex.COMMUNICATION) + 1

/// @notice Represents the data needed for a public key registration
/// @dev Includes the public key coordinates and ECDSA signature for verification
struct PublicKeyRegistration {
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

/// @notice Represents a committee member with their keys, roles, and balance
/// @dev Contains all information needed to manage a member's participation
struct Member {
    /// @notice Array of public keys indexed by PublicKeyIndex
    /// @dev Contains TAKE, COVENANT, and COMMUNICATION keys
    bytes32[] publicKeys;
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
    bytes32 aggregatedKey;
    /// @notice Array of committee members with their roles
    CommitteeMember[] members;
    /// @notice Address of the committee leader
    /// @dev TODO: add leader logic
    address leaderAddress;
    /// @notice Index of the operator take address
    uint256 operatorTakeIndex;
}

/// @notice Represents a committee that is in the process of being formed
/// @dev Used to track committee formation progress and member data collection
struct PendingCommittee {
    /// @notice The committee being formed
    Committee committee;
    /// @notice Timestamp when the pending committee was created
    uint256 createdAt;
    /// @notice Number of members that have not provided their data yet
    uint16 missingData;
    /// @notice Mapping of member addresses to their pending data
    mapping(address memberAddress => PendingCommitteeData) data;
}

/// @notice Represents pending data for a member in committee formation
/// @dev Contains the aggregated key provided by the member and committee status
struct PendingCommitteeData {
    /// @notice Aggregated key provided by the member
    bytes32 aggregatedKey;
    /// @notice Whether the member is included in the committee
    bool inCommittee;
}

/// @notice Interface for managing committee registration and formation in the union bridge
/// @dev This interface provides functions for member registration, committee formation,
/// @dev and balance management for the committee system
interface ICommitteeRegistry {
    /// @notice Applies to participate in a stream with a specific role
    /// @dev Registers public keys and deposits required bond for the requested role
    /// @param _requestedStream The stream denomination to apply for
    /// @param _requestedRole The role requested in the committee
    /// @param _publicKeys Array of public key registrations for TAKE, COVENANT, and COMMUNICATION
    function applyToStream(
        StreamDenomination _requestedStream,
        Role _requestedRole,
        PublicKeyRegistration[] calldata _publicKeys
    ) external payable;

    /// @notice Unsubscribes from a stream and set as available balance the pre-staked balance
    /// @param _stream The stream denomination to unsubscribe from
    function unsubscribeFromStream(StreamDenomination _stream) external;

    /// @notice Withdraws available balance to the caller's address
    /// @dev Can only withdraw balance that is not pre-staked or staked
    function withdrawAvailableBalance() external;

    /// @notice Retrieves all public keys for a specific member
    /// @param _address The member's address
    /// @return publicKeys Array of public keys indexed by PublicKeyIndex
    function getMemberPublicKeys(address _address) external view returns (bytes32[] memory publicKeys);

    /// @notice Gets the requested role for a member in a specific stream
    /// @param _address The member's address
    /// @param _denomination The stream denomination
    /// @return The requested role for the member
    function getMemberRequestedRole(address _address, StreamDenomination _denomination) external view returns (Role);

    /// @notice Gets the available balance for a member
    /// @param _address The member's address
    /// @return The available balance that can be withdrawn
    function getMemberAvailableBalance(address _address) external view returns (uint256);

    /// @notice Gets the pre-staked balance for a member in a specific stream
    /// @param _address The member's address
    /// @param _denomination The stream denomination
    /// @return The pre-staked balance for the stream
    function getMemberPreStakedBalance(address _address, StreamDenomination _denomination)
        external
        view
        returns (uint256);

    /// @notice Gets the staked balance for a member in a specific packet
    /// @param _address The member's address
    /// @param _denomination The stream denomination
    /// @param _packetNumber The packet number
    /// @return amount The staked amount in the packet
    function getMemberStakedBalance(address _address, StreamDenomination _denomination, uint64 _packetNumber)
        external
        view
        returns (uint256 amount);

    /// @notice Gets all candidates for a specific role in a stream
    /// @param _denomination The stream denomination
    /// @param _role The role to get candidates for
    /// @return Array of candidate addresses
    function getCommitteeCandidates(StreamDenomination _denomination, Role _role)
        external
        view
        returns (address[] memory);

    /// @notice Gets a committee by its ID
    /// @param _committeeId The committee ID
    /// @return Committee The complete committee information
    function getCommittee(uint256 _committeeId) external view returns (Committee calldata);

    /// @notice Gets all members of a specific committee
    /// @param _committeeId The committee ID
    /// @return Array of committee members with their roles
    function getCommitteeMembers(uint256 _committeeId) external view returns (CommitteeMember[] memory);

    /// @notice Gets the TAKE public key for a specific member
    /// @param _memberAddress The member's address
    /// @return The TAKE public key (x-coordinate only)
    function getMemberTakePubKey(address _memberAddress) external view returns (bytes32);

    /// @notice Gets the minimum deposit required for a stream
    /// @param _denomination The stream denomination
    /// @return The minimum deposit amount in wei
    function getMinimumDeposit(StreamDenomination _denomination) external view returns (uint256);

    /// @notice Deposits member information for committee formation
    /// @dev Called by members to provide their aggregated key for pending committee
    /// @param _streamId The stream ID for the pending committee
    /// @param _aggregatedKey The aggregated public key provided by the member
    function depositMemberInfoForCommittee(uint64 _streamId, bytes32 _aggregatedKey) external;

    /// @notice Creates a new committee for a stream
    /// @dev This function is called when the slot usage threshold is reached
    /// @param _streamId The stream ID to create a new committee for
    function createCommittee(uint64 _streamId) external;

    /// @notice Checks if there is a pending committee for the stream and it's expired
    /// @param _streamId The stream ID to check for a pending committee
    /// @return True if the pending committee exists and is expired
    function isPendingCommitteeExpired(uint64 _streamId) external view returns (bool);

    /// @notice Returns the pending committee for the stream
    /// @dev This function will revert if the committee is not pending or if it's expired
    /// @param _streamId The stream ID to get the pending committee for
    /// @return committee The pending committee
    /// @return createdAt The timestamp when the pending committee was created
    /// @return missingData The number of members that have not provided their data yet
    function getPendingCommittee(uint64 _streamId)
        external
        view
        returns (Committee memory committee, uint256 createdAt, uint256 missingData);

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

    /// @notice Sets the minimum members required for a committee
    /// @dev Only callable by the contract owner
    /// @param _minMembers The minimum number of members required for a committee
    function setCommitteeMinMembers(uint256 _minMembers) external;

    /// @notice Gets the minimum watchtowers required for a committee
    /// @return The minimum number of watchtowers required
    function minCommitteeWatchtowers() external view returns (uint256);

    /// @notice Gets the minimum operators required for a committee
    /// @return The minimum number of operators required
    function minCommitteeOperators() external view returns (uint256);

    /// @notice Gets the minimum members required for a committee
    /// @return The minimum number of members required
    function minCommitteeMembers() external view returns (uint256);

    /// @notice Gets the operator take address for a specific committee
    /// @param committeeId The ID of the committee
    /// @param signatureData The signature data for the committee members
    /// @return The operator take address
    function getOperatorTakeAddress(uint256 committeeId, SignatureData[] memory signatureData)
        external
        returns (address);

    /// @notice Release the committee members from a packet (return or reapply staked money)
    function releaseCommittee(uint64 _streamId, uint64 _packetNumber) external;

    /// @notice Set the ReApply flag for a stream
    /// @param _denomination The denomination of the stream
    /// @param _reApply The reapply flag to set
    function setReApplyForStream(StreamDenomination _denomination, bool _reApply) external;

    /// @notice Get the ReApply flag for a stream
    /// @param _denomination The denomination of the stream
    /// @return reApply The reapply flag for the stream
    function getReApplyForStream(StreamDenomination _denomination) external view returns (bool);

    // ===================== Events =====================
    /// @notice Event emitted when a new committee is created
    /// @param committeeId The ID of the newly created committee
    /// @param _committee The committee information
    event NewCommittee(uint256 indexed committeeId, Committee _committee);

    /// @notice Event emitted when a new pending committee is created
    /// @param streamId The stream ID for the pending committee
    /// @param _committee The pending committee information
    event NewPendingCommittee(uint256 indexed streamId, Committee _committee);

    /// @notice Event emitted when a new member is registered
    /// @param publicKeys The public keys of the new member
    event NewMember(bytes32[] indexed publicKeys);

    /// @notice Event emitted when a member unsubscribes from a stream
    /// @param member The member's address
    /// @param stream The stream denomination
    event MemberUnsubscribedFromStream(address indexed member, StreamDenomination stream);

    /// @notice Event emitted when a member's balance is updated
    /// @param memberAddress The member's address
    /// @param availableBalance The new available balance
    /// @param preStakedBalance The new pre-staked balance
    event NewAvailableBalance(address indexed memberAddress, uint256 availableBalance, uint256 preStakedBalance);

    /// @notice Event emitted when available balance is withdrawn
    /// @param sender The address that withdrew the balance
    /// @param amount The amount withdrawn
    event AvailableBalanceRetrieved(address indexed sender, uint256 amount);

    /// @notice Event emitted when a security bond is deposited
    /// @param sender The address that deposited the bond
    /// @param requestedStream The stream denomination
    /// @param requestedRole The requested role
    /// @param amount The amount deposited
    event NewSecurityBondDeposit(
        address indexed sender, StreamDenomination requestedStream, Role requestedRole, uint256 amount
    );

    /// @notice Event emitted when there are not enough watchtowers
    /// @param denomination The stream denomination
    /// @param required The required number of watchtowers
    /// @param missing The number of missing watchtowers
    event MissingWatchtowers(StreamDenomination denomination, uint256 required, uint256 missing);

    /// @notice Event emitted when there are not enough operators
    /// @param denomination The stream denomination
    /// @param required The required number of operators
    /// @param missing The number of missing operators
    event MissingOperators(StreamDenomination denomination, uint256 required, uint256 missing);

    /// @notice Event emitted when there are not enough members
    /// @param denomination The stream denomination
    /// @param required The required number of members
    /// @param missing The number of missing members
    event MissingMembers(StreamDenomination denomination, uint256 required, uint256 missing);

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
    event CommitteeMinMembersUpdated(uint256 minMembers);

    /// @notice Event emitted when member info is deposited for committee formation
    /// @param streamId The stream ID
    /// @param member The member's address
    /// @param aggregatedKey The aggregated key provided by the member
    event MemberInfoDeposited(uint64 indexed streamId, address indexed member, bytes32 aggregatedKey);

    /// @notice Event emitted when no honest operators remain in a committee
    /// @param committeeId The ID of the committee with no honest operators
    event NoRemainingHonestOperators(uint256 committeeId);

    /// @notice Event emitted when a member reapplies to a stream
    /// @param memberAddress The member's address
    /// @param denomination The stream denomination
    /// @param role The role requested by the member
    /// @param preStakedBalance The pre-staked balance for the application
    event MemberReApplied(
        address indexed memberAddress, StreamDenomination denomination, Role role, uint256 preStakedBalance
    );

    /// @notice Event emitted when a member's reapply flag is updated
    /// @param memberAddress The member's address
    /// @param denomination The stream denomination
    /// @param reApply The new reapply flag value
    event MemberReApplyUpdated(address indexed memberAddress, StreamDenomination denomination, bool reApply);

    // Errors
    /// @notice Thrown when streams and roles arrays have different lengths
    /// @param streamsLength The length of the streams array
    /// @param rolesLength The length of the roles array
    error RequestedDifferentStreamsAndRolesLength(uint256 streamsLength, uint256 rolesLength);

    /// @notice Thrown when no roles are requested
    error RequestedNoRoles();

    /// @notice Thrown when multiple roles are requested for the same stream
    /// @param stream The stream denomination
    /// @param role1 The first requested role
    /// @param role2 The second requested role
    error RequestedMultipleRolesForStream(StreamDenomination stream, Role role1, Role role2);

    /// @notice Thrown when a member is already registered
    /// @param memberAddress The address of the already registered member
    error AlreadyRegisteredMember(address memberAddress);

    /// @notice Thrown when there are too many members per committee
    /// @param maxMemebersPerCommittee The maximum number of members allowed per committee
    error TooManyMembersPerComitee(uint256 maxMemebersPerCommittee);

    /// @notice Thrown when a committee is already registered
    /// @param committeeId The ID of the already registered committee
    error AlreadyRegisteredCommittee(uint256 committeeId);

    /// @notice Thrown when a member is not found
    /// @param memberAddress The address of the member not found
    error MemberNotFound(address memberAddress);

    /// @notice Thrown when a committee is not in pending state
    /// @param streamId The stream ID
    error CommitteeIsNotPending(uint64 streamId);

    /// @notice Thrown when a pending committee is not expired
    /// @param streamId The stream ID
    /// @param createdAt The creation timestamp
    /// @param expireAt The expiration timestamp
    error PendingCommitteeNotExpired(uint64 streamId, uint256 createdAt, uint256 expireAt);

    /// @notice Thrown when the aggregated key is invalid
    error InvalidAgregatedKey();

    /// @notice Thrown when public keys are repeated
    /// @param index The index of the first occurrence
    /// @param publicKeyX The X-coordinate of the public key
    /// @param repeatedIndex The index of the repeated occurrence
    /// @param repeatedPublicKeyX The X-coordinate of the repeated public key
    error RepeatedPublicKeys(uint256 index, bytes32 publicKeyX, uint256 repeatedIndex, bytes32 repeatedPublicKeyX);

    /// @notice Thrown when a public key is zero
    /// @param index The index of the invalid public key
    /// @param publicKeyX The X-coordinate of the public key
    /// @param publicKeyY The Y-coordinate of the public key
    error InvalidZeroPublicKey(uint256 index, bytes32 publicKeyX, bytes32 publicKeyY);

    /// @notice Thrown when the public keys array length is invalid
    /// @param publicKeysLength The actual length
    /// @param expectedLength The expected length
    error InvalidPublicKeysLength(uint256 publicKeysLength, uint256 expectedLength);

    /// @notice Thrown when a public key doesn't match the expected value
    /// @param index The index of the public key
    /// @param currentPubKey The current public key
    /// @param newPubKey The new public key
    error PublicKeyMismatch(uint256 index, bytes32 currentPubKey, bytes32 newPubKey);

    /// @notice Thrown when a signature is zero
    /// @param index The index of the invalid signature
    /// @param publicKey The public key registration with invalid signature
    error InvalidZeroSignature(uint256 index, PublicKeyRegistration publicKey);

    /// @notice Thrown when a signature is invalid
    /// @param index The index of the invalid signature
    /// @param publicKey The public key registration with invalid signature
    /// @param recoveredSignerAddress The address recovered from the signature
    /// @param signerAddress The expected signer address
    error InvalidSignature(
        uint256 index, PublicKeyRegistration publicKey, address recoveredSignerAddress, address signerAddress
    );

    /// @notice Thrown when there are no committee members
    error NoCommitteeMembers();

    /// @notice Thrown when a member is not in the committee
    /// @param streamId The stream ID
    /// @param memberAddress The member's address
    error MemberNotInCommittee(uint64 streamId, address memberAddress);

    /// @notice Thrown when member info is already deposited
    /// @param memberAddress The member's address
    error MemberInfoAlreadyDeposited(address memberAddress);

    /// @notice Thrown when a committee is not found
    /// @param committeeId The committee ID
    error CommitteeNotFound(uint256 committeeId);

    /// @notice Thrown when an account is not authorized
    /// @param account The unauthorized account
    error UnauthorizedAccount(address account);

    /// @notice Thrown when an address is zero
    error InvalidZeroAddress();

    /// @notice Thrown when no role is requested for a stream
    /// @param stream The stream denomination
    error RequestedNoneRoleForStream(StreamDenomination stream);

    /// @notice Thrown when there are too many members
    /// @param maxMembers The maximum number of members allowed
    error TooManyMembers(uint256 maxMembers);

    /// @notice Thrown when there are not enough watchtowers
    /// @param streamId The stream ID
    error NotEnoughWatchtowers(uint64 streamId);

    /// @notice Thrown when there are not enough operators
    /// @param streamId The stream ID
    error NotEnoughOperators(uint64 streamId);

    /// @notice Thrown when there are not enough members
    /// @param streamId The stream ID
    error NotEnoughMembers(uint64 streamId);

    /// @notice Thrown when a member is already registered for a stream
    /// @param memberAddress The member's address
    /// @param requestedStream The requested stream
    /// @param requestedRole The requested role
    /// @param currentRole The current role
    error MemberAlreadyRegisteredForStream(
        address memberAddress, StreamDenomination requestedStream, Role requestedRole, Role currentRole
    );

    /// @notice Thrown when a member is not a candidate for a stream
    /// @param member The member's address
    /// @param stream The stream denomination
    error MemberIsNotCandidateForStream(address member, StreamDenomination stream);

    /// @notice Thrown when there is no available balance to withdraw
    /// @param member The member's address
    error NoAvailableBalanceToWithdraw(address member);

    /// @notice Thrown when a member is not registered
    /// @param memberAddress The member's address
    error MemberNotRegistered(address memberAddress);

    /// @notice Thrown when the deposit bond is too low
    /// @param sent The amount sent
    /// @param minDeposit The minimum deposit required
    error DespositBondTooLow(uint256 sent, uint256 minDeposit);

    /// @notice Thrown when RSK transfer fails
    /// @param memberAddress The member's address
    /// @param amount The amount that failed to transfer
    error FailedToSendRSK(address memberAddress, uint256 amount);

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
    error TakeOperatorNotFound(uint256 committeeId);

    // Internal Errors
    /// @notice Thrown when member index is out of bounds
    /// @param memberIndex The invalid member index
    error _MemberIndexOutOfBounds(uint16 memberIndex);

    /// @notice Thrown when committee creation fails
    /// @param streamId The stream ID
    /// @param status The status indicating why creation failed
    error _FailedToCreateCommittee(uint64 streamId, PendingCommitteeStatus status);

    /// @notice Thrown when a member's take public key doesn't match the signature public key
    /// @param committeeId The ID of the committee
    /// @param memberAddress The member's address
    /// @param memberPubKey The member's registered take public key
    /// @param signaturePubKeyX The public key X-coordinate from the signature
    error _InvalidTake1PubKey(
        uint256 committeeId, address memberAddress, bytes32 memberPubKey, bytes32 signaturePubKeyX
    );

    /// @notice Thrown when a member's pre-staked balance doesn't match their requested role requirements
    /// @param memberAddress The member's address
    /// @param denomination The stream denomination
    /// @param preStakedBalance The member's pre-staked balance
    /// @param requestedRole The role requested by the member
    error _inconsistentPreStakedBalanceAndRole(
        address memberAddress, StreamDenomination denomination, uint256 preStakedBalance, Role requestedRole
    );
}
