// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {StreamDenomination} from "./IStreamManager.sol";
import {IPegManager} from "./IPegManager.sol";

enum Role {
    None,
    Operator,
    Watchtower
}

enum PendingCommitteeStatus {
    Success,
    NotEnoughMembers,
    NotEnoughOperators,
    NotEnoughWatchtowers
}

struct Balance {
    uint256 available;
    uint256[] preStaked;
    mapping(uint64 packetNumber => uint256 amount)[] staked; // denominationIndex => (packetId => amount)
}

struct Member {
    bytes32 publicKey;
    mapping(StreamDenomination => Role) requestedRoles;
    Balance balance;
    mapping(string key => string value) data;
}

struct CommitteeMember {
    uint16 index; // from the members array
    Role role;
}

struct Committee {
    bytes32 aggregatedKey; // BTC public key of the commitee (TODO: Rename to aggregatedKey)
    CommitteeMember[] memberIndexesAndRoles; // Indices and roles of the members from the members array
    uint8 leaderIndex; // TODO add leader logic
}

struct PendingCommittee {
    Committee committee;
    uint256 createdAt;
    uint16 missingData;
    mapping(bytes32 memberPubKey => PendingCommitteeData) data;
}

struct PendingCommitteeData {
    bytes32 aggregatedKey; // agregated key provided by the member
    bool inCommittee;
}

interface ICommitteeRegistry {
    function applyToStream(bytes32 _publicKey, StreamDenomination _requestedStream, Role _requestedRole)
        external
        payable;

    function unsubscribeFromStream(StreamDenomination _stream) external;

    function withdrawAvailableBalance() external;

    function getMemberPublicKey(address _address) external view returns (bytes32);

    function getMemberRequestedRole(address _address, StreamDenomination _denomination) external view returns (Role);

    function getMemberAvailableBalance(address _address) external view returns (uint256);

    function getMemberPreStakedBalance(address _address, StreamDenomination _denomination)
        external
        view
        returns (uint256);

    function getMemberStakedBalance(address _address, StreamDenomination _denomination, uint64 _packetNumber)
        external
        view
        returns (uint256 amount);

    function getCommitteeCandidates(StreamDenomination _denomination, Role _role)
        external
        view
        returns (uint16[] memory);

    function getCommittee(uint256 _committeeId) external view returns (Committee calldata);

    function getCommitteeMembers(uint256 _committeeId) external view returns (CommitteeMember[] memory);

    function getMemberPubKeyByIndex(uint16 _memberIndex) external view returns (bytes32);

    function getMemberIndexByAddress(address _address) external view returns (uint16);

    function getMinimumDeposit(StreamDenomination _denomination) external view returns (uint256);

    /// @notice Create a new committee for a stream
    /// @param _streamId The stream id to create a new committee for
    /// @dev This function is called when the slot usage threshold is reached
    function createCommittee(uint64 _streamId) external;

    /// @notice Return true if there is a pending committee for the stream and it's expired
    /// @param _streamId The stream id to check for a pending committee
    function isPendingCommitteeExpired(uint64 _streamId) external view returns (bool);

    /// @notice Returns the pending committee for the stream
    /// @param _streamId The stream id to get the pending committee for
    /// @return committee The pending committee
    /// @return createdAt The timestamp when the pending committee was created
    /// @return missingData The number of members that have not provided their data yet
    /// @dev This function should be called after the pending committee is created it will revert if the committee is not pending
    function getPendingCommittee(uint64 _streamId)
        external
        view
        returns (Committee memory committee, uint256 createdAt, uint256 missingData);

    /// @notice Set Peg Manager address
    /// @param _pegManager The address of the Peg Manager contract
    function setPegManager(IPegManager _pegManager) external;

    /// @notice Set the pending committee timeout
    /// @param _timeout The timeout in seconds for the pending committee
    function setPendingCommitteeTimeout(uint256 _timeout) external;

    /// ===================== Events =========================
    event NewCommittee(uint256 indexed committeeId, Committee _committee);
    event NewPendingCommittee(uint256 indexed streamId, Committee _committee);
    event NewMember(bytes32 indexed publicKey);
    event MemberUnsubscribedFromStream(address indexed member, StreamDenomination stream);
    event NewAvailableBalance(address indexed sender, uint256 balance, uint256 preStakedBalance);
    event AvailableBalanceRetrieved(address indexed sender, uint256 amount);
    event NewSecurityBondDeposit(
        address indexed sender, StreamDenomination requestedStream, Role requestedRole, uint256 amount
    );
    event MissingWatchtowers(StreamDenomination denomination, uint256 required, uint256 missing);
    event MissingOperators(StreamDenomination denomination, uint256 required, uint256 missing);
    event MissingMembers(StreamDenomination denomination, uint256 required, uint256 missing);

    /// ==================== Errors =====================
    error RequestedDifferentStreamsAndRolesLength(uint256 streamsLength, uint256 rolesLength);
    error RequestedNoRoles();
    error RequestedMultipleRolesForStream(StreamDenomination stream, Role role1, Role role2);
    error AlreadyRegisteredMember(address memberAddress);
    error TooManyMembersPerComitee(uint256 maxMemebersPerCommittee);
    error AlreadyRegisteredCommittee(uint256 committeeId);
    error MemberNotFound(address memberAddress);
    error CommitteeIsNotPending(uint64 streamId);
    error PendingCommitteeNotExpired(uint64 streamId, uint256 createdAt, uint256 expireAt);
    error InvalidAgregatedKey();
    error NoCommitteeMembers();
    error MemberNotInCommittee(bytes32);
    error MemberAlreadyUpdated(bytes32);
    error CommitteeNotFound(uint256 committeeId);
    error UnauthorizedAccount(address account);
    error InvalidZeroAddress();
    error RequestedNoneRoleForStream(StreamDenomination stream);
    error NonRegisteredMember(address memberAddress);
    error TooManyMembers(uint256 maxMembers);
    error NotEnoughWatchtowers(uint64 streamId);
    error NotEnoughOperators(uint64 streamId);
    error NotEnoughMembers(uint64 streamId);
    error MemberAlreadyRegisteredForStream(
        address memberAddress, StreamDenomination requestedStream, Role requestedRole, Role currentRole
    );
    error MemberIsNotCandidateForStream(address member, StreamDenomination stream);
    error NoAvailableBalanceToWithdraw(address member);
    error MemberIndexNotFound(uint16 memberIndex);
    error MemberNotRegistered(address memberAddress);
    error DespositBondTooLow(uint256 sent, uint256 minDeposit);
    error FailedToSendRSK(address memberAddress, uint256 amount);
    error PublicKeyMismatch(bytes32 currentPubKey, bytes32 newPubKey);

    /// ================ Internal Errors =================
    error _MemberIndexOutOfBounds(uint16 memberIndex);
    error _FailedToCreateCommittee(uint64 streamId, PendingCommitteeStatus status);
    error InvalidZeroTimeout();
}
