// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {StreamDenomination} from "./IStreamManager.sol";
import {Role, CommitteeMember, UTXO, PendingCommitteeStatus} from "./ICommitteeRegistry.sol";

/// @dev Amount of bytes32 chunks for DER-encoded RSA public key
uint8 constant RSA_PUBLIC_KEY_CHUNKS = 10;

/// @notice Represents the different types of public keys a member can register
/// @dev Each key type serves a specific purpose in the committee operations
enum PublicKeyType {
    /// @notice Public key used for take operations (normal peg-out)
    TAKE,
    /// @notice Public key used for dispute operations (dispute resolution)
    DISPUTE,
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
    /// @notice DISPUTE public key (ECDSA) - no validation
    ECDSAPublicKey disputeKey;
    /// @notice COMMUNICATION public key (RSA) - input validation only
    RSAPublicKey communicationKey;
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

/// @notice Member public keys structure for members
/// @dev Contains different key types for different purposes
struct MemberKeys {
    /// @notice TAKE public key (ECDSA)
    bytes32 takePubKey;
    /// @notice DISPUTE public key (ECDSA)
    bytes32 disputePubKey;
    /// @notice COMMUNICATION public key (RSA)
    RSAPublicKey communicationPubKey;
}

/// @notice Represents a committee member with their keys, roles, and balance
/// @dev Contains all information needed to manage a member's participation
struct Member {
    /// @notice Member public keys for different purposes
    /// @dev Contains TAKE (ECDSA), DISPUTE (ECDSA), and COMMUNICATION (RSA) keys
    MemberKeys publicKeys;
    /// @notice Balance and staking information for the member
    Balance balance;
    /// @notice Additional data stored as key-value pairs
    mapping(string key => string value) data;
}

/// @title IMemberRegistry
/// @notice Interface for managing committee member registration, applications, and balance tracking
/// @dev Handles member lifecycle operations including registration, candidacy, and balance management
interface IMemberRegistry {
    // ===================== Member Lifecycle =====================

    /// @notice Internal function to handle member application to stream
    /// @dev Called by CommitteeRegistry to handle member registration and candidacy
    /// @param _memberAddress The address of the member applying
    /// @param _stream The stream denomination to apply for
    /// @param _role The role requested in the committee
    /// @param _publicKeys Member registration public keys
    /// @param _fundingUTXO The Bitcoin UTXO that will be used for the member funding
    function applyToStream(
        address _memberAddress,
        StreamDenomination _stream,
        Role _role,
        MemberRegistrationKeys calldata _publicKeys,
        UTXO calldata _fundingUTXO
    ) external payable;

    /// @notice Internal function to handle member unsubscription from stream
    /// @dev Called by CommitteeRegistry after pending committee checks
    /// @dev Only callable by CommitteeRegistry contract
    /// @param _memberAddress The address of the member unsubscribing
    /// @param _denomination The stream denomination to unsubscribe from
    function unsubscribeFromStream(address _memberAddress, StreamDenomination _denomination) external;

    /// @notice Withdraws available balance to the caller's address
    /// @dev Can only withdraw balance that is not pre-staked or staked
    /// @dev Only callable when contract is unpaused
    function withdrawAvailableBalance() external;

    /// @notice Randomly selects members to form a new committee for a given stream
    /// @dev Pseudo-randomly select at least minCommitteeWatchtowers watchtowers and minCommitteeOperators operators.
    /// @dev reverts with notEnoughWatchtowers if there are fewer than minCommitteeWatchtowers watchtower candidates
    /// @dev reverts with notEnoughOperators if there are fewer than minCommitteeOperators operator candidates
    /// @dev Only callable by CommitteeRegistry contract
    /// @param _streamId The stream ID to select committee for
    /// @param _minWatchtowers Minimum number of watchtowers required
    /// @param _minOperators Minimum number of operators required
    /// @param _totalMemberCount Total number of members in committee
    /// @return CommitteeMember[] Array of selected committee members
    /// @return PendingCommitteeStatus Status of the selection process
    function selectCommittee(
        uint64 _streamId,
        uint256 _minWatchtowers,
        uint256 _minOperators,
        uint256 _totalMemberCount
    ) external returns (CommitteeMember[] memory, PendingCommitteeStatus);

    /// @notice Internal function to handle committee member release operations
    /// @dev Called by CommitteeRegistry after committee completion
    /// @param _committeeMembers Array of committee members to release
    /// @param _streamId The stream ID
    /// @param _packetNumber The packet number
    function releaseCommitteeMembers(CommitteeMember[] memory _committeeMembers, uint64 _streamId, uint64 _packetNumber)
        external;

    /// @notice External function to handle re-addition of members as candidates
    /// @dev Called by CommitteeRegistry after pending committee reset
    /// @param _denomination The stream of the pending committee
    /// @param _member The member to re-add as candidate
    function reAddCandidateToStream(StreamDenomination _denomination, CommitteeMember memory _member) external;

    /// @notice Sets the reapply flag for a member in a specific stream
    /// @dev Controls whether the member will automatically reapply after committee release
    /// @param _denomination The stream denomination to set the flag for
    /// @param _reApply True to automatically reapply, false to receive balance as available
    function setReApplyForStream(StreamDenomination _denomination, bool _reApply) external;

    /// @notice Sets the reapply flag as false for a member in a specific stream
    /// @dev Controls that the member will not automatically reapply after committee release
    /// @param _memberAddress The member adress
    /// @param _denomination The stream denomination to set the flag for
    function disableMemberReApplyForStream(address _memberAddress, StreamDenomination _denomination) external;

    // ===================== Member Queries =====================

    /// @notice Returns whether the address belongs to a member
    /// @param _address The address
    /// @return True when address was ever a member, false otherwise
    function isMember(address _address) external view returns (bool);

    /// @notice Gets the TAKE public key for a specific member
    /// @param _address The member's address
    /// @return The TAKE public key (x-coordinate only)
    function getMemberTakePubKey(address _address) external view returns (bytes32);

    /// @notice Gets the COMMUNICATION public key for a specific member
    /// @param _address The member's address
    /// @return The COMMUNICATION public key (RSA struct)
    function getMemberComPubKey(address _address) external view returns (RSAPublicKey memory);

    /// @notice Retrieves the DISPUTE public key for a specific member
    /// @param _address The member's address
    /// @return The member's dispute public key (x-only)
    function getMemberDisputePubKey(address _address) external view returns (bytes32);

    /// @notice Retrieves all public keys for a specific member
    /// @param _address The member's address
    /// @return publicKeys Member public keys structure
    function getMemberPublicKeys(address _address) external view returns (MemberKeys memory publicKeys);

    /// @notice Gets the requested role for a member in a specific stream
    /// @param _memberAddress The member's address
    /// @param _denomination The stream denomination
    /// @return The requested role for the member
    function getMemberRequestedRole(address _memberAddress, StreamDenomination _denomination)
        external
        view
        returns (Role);

    /// @notice Gets the available balance for a member
    /// @param _address The member's address
    /// @return The available balance that can be withdrawn
    function getMemberAvailableBalance(address _address) external view returns (uint256);

    /// @notice Gets the pre-staked balance for a member in a specific stream
    /// @param _memberAddress The member's address
    /// @param _denomination The stream denomination
    /// @return The pre-staked balance for the stream
    function getMemberPreStakedBalance(address _memberAddress, StreamDenomination _denomination)
        external
        view
        returns (uint256);

    /// @notice Gets the staked balance for a member in a specific stream and packet
    /// @param _address The member's address
    /// @param _denomination The stream denomination
    /// @param _packetNumber The packet number
    /// @return amount The staked amount in the packet
    function getMemberStakedBalance(address _address, StreamDenomination _denomination, uint64 _packetNumber)
        external
        view
        returns (uint256 amount);

    /// @notice Gets the funding UTXO for a member in a specific stream
    /// @param _streamId The stream ID
    /// @param _memberAddress The member's address
    /// @return The funding UTXO for the member's application to the stream
    function getMemberFundingUTXO(uint64 _streamId, address _memberAddress) external view returns (UTXO memory);

    /// @notice Gets all candidates for a specific role in a stream
    /// @param _denomination The stream denomination
    /// @param _role The role to get candidates for
    /// @return Array of candidate addresses
    function getCommitteeCandidates(StreamDenomination _denomination, Role _role)
        external
        view
        returns (address[] memory);

    /// @notice Gets the reapply flag for a member in a specific stream
    /// @param _denomination The stream denomination to check
    /// @return True if the member will automatically reapply, false otherwise
    function getReApplyForStream(StreamDenomination _denomination) external view returns (bool);

    // ===================== Committee Integration =====================

    /// @notice Moves candidates balance from pre staked to staked
    /// @dev Called by CommitteeRegistry during committee formation
    /// @dev Only callable by Committee Registry contract
    /// @param _members Array of committee members
    /// @param _denomination The stream denomination
    /// @param _packetNumber The packet number
    function stakePreStakedCandidatesBalance(
        CommitteeMember[] memory _members,
        StreamDenomination _denomination,
        uint64 _packetNumber
    ) external;

    // ===================== Events =====================

    /// @notice Event emitted when a new member is registered
    /// @param member The member address
    /// @param publicKeys The public keys of the new member
    event NewMember(address indexed member, MemberKeys publicKeys);

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

    /// @notice Event emitted when there are not enough watchtowers for committee formation
    /// @param denomination The stream denomination
    /// @param required Number of watchtowers required
    /// @param missing Number of watchtowers missing
    event MissingWatchtowers(StreamDenomination denomination, uint256 required, uint256 missing);

    /// @notice Event emitted when there are not enough operators for committee formation
    /// @param denomination The stream denomination
    /// @param required Number of operators required
    /// @param missing Number of operators missing
    event MissingOperators(StreamDenomination denomination, uint256 required, uint256 missing);

    /// @notice Event emitted when there are not enough total members for committee formation
    /// @param denomination The stream denomination
    /// @param required Number of members required
    /// @param missing Number of members missing
    event MissingMembers(StreamDenomination denomination, uint256 required, uint256 missing);

    /// @notice Event emitted when the bridge address is updated
    /// @param newBridge The new bridge address
    event BridgeUpdated(address indexed newBridge);

    // ===================== Errors =====================

    /// @notice Thrown when a member is not registered
    /// @param memberAddress The member's address
    error MemberNotRegistered(address memberAddress);

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

    /// @notice Thrown when the funding UTXO transaction ID is zero
    /// @param utxo The complete UTXO with zero transaction ID
    error ZeroUTXOTxid(UTXO utxo);

    /// @notice Thrown when the funding UTXO amount is zero
    /// @param utxo The complete UTXO with zero amount
    error ZeroUTXOAmount(UTXO utxo);

    /// @notice Thrown when no role is requested for a stream
    /// @param stream The stream denomination
    error RequestedNoneRoleForStream(StreamDenomination stream);

    /// @notice Thrown when there are too many candidates for a stream
    /// @param denomination The stream denomination
    /// @param role The role for which there are too many candidates
    error TooManyCandidatesForStream(StreamDenomination denomination, Role role);

    /// @notice Thrown when a EDCSA public key is invalid (zero or not on curve)
    /// @param keyType The type of the public key (TAKE, DISPUTE, or COMMUNICATION)
    /// @param publicKeyX The X-coordinate of the public key
    /// @param publicKeyY The Y-coordinate of the public key
    error InvalidEDCSAPublicKey(PublicKeyType keyType, bytes32 publicKeyX, bytes32 publicKeyY);

    /// @notice Thrown when a RSA public key is zero
    /// @param keyType The type of the public key (TAKE, DISPUTE, or COMMUNICATION)
    error InvalidZeroRSAPublicKey(PublicKeyType keyType);

    /// @notice Thrown when a public key doesn't match the expected value
    /// @param keyType The type of the public key (TAKE, DISPUTE, or COMMUNICATION)
    /// @param currentPubKey The current public key
    /// @param newPubKey The new public key
    error PublicKeyMismatch(PublicKeyType keyType, bytes32 currentPubKey, bytes32 newPubKey);

    /// @notice Thrown when a signature is zero
    /// @param keyType The type of the public key (TAKE, DISPUTE, or COMMUNICATION)
    /// @param publicKey The public key registration with invalid signature
    error InvalidZeroEDCSASignature(PublicKeyType keyType, ECDSAPublicKey publicKey);

    /// @notice Thrown when a signature is invalid
    /// @param keyType The type of the public key (TAKE, DISPUTE, or COMMUNICATION)
    /// @param publicKey The public key registration with invalid signature
    /// @param recoveredSignerAddress The address recovered from the signature
    /// @param signerAddress The expected signer address
    error InvalidEDCSASignature(
        PublicKeyType keyType, ECDSAPublicKey publicKey, address recoveredSignerAddress, address signerAddress
    );

    /// @notice Thrown when a member's pre-staked balance doesn't match their requested role requirements
    /// @param memberAddress The member's address
    /// @param denomination The stream denomination
    /// @param preStakedBalance The member's pre-staked balance
    /// @param requestedRole The role requested by the member
    error _inconsistentPreStakedBalanceAndRole(
        address memberAddress, StreamDenomination denomination, uint256 preStakedBalance, Role requestedRole
    );

    /// @notice Thrown when an account is not authorized to perform an operation
    /// @param account The unauthorized account address
    error UnauthorizedAccount(address account);

    // --- TESTNET ONLY: Force close committee functionality ---
    // TODO: Remove before mainnet deployment
    function forceReleaseCommitteeMembers_TESTNET(
        uint64 _streamId,
        uint64 _packetNumber,
        address[] memory _committeeMembersAddresses
    ) external;

    event CommitteeMembersForceReleased(uint64 indexed streamId, uint64 indexed packetNumber);

    /// @notice WARNING! ONLY FOR TESTNET Forces a withdrawal of the contract's balance to a specified address
    /// @dev Only callable on testnet, this function will leave the contract in a broken state and should be used only as a last resort
    /// @param _to The address to which the balance will be sent
    function forceExit_TESTNET(address _to) external;

    event ForceExit(address indexed to, uint256 amount);
    // --- END TESTNET ONLY ---
}
