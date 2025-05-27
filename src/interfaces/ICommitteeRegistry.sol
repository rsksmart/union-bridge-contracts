// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {StreamDenomination} from "./IStreamManager.sol";
import {IPegManager} from "./IPegManager.sol";

enum Role {
    None,
    Operator,
    Watchtower
}

struct Member {
    bytes32 publicKey;
    mapping(StreamDenomination => Role) requestedRoles;
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
    uint256 expireAt;
    uint16 missingData;
    mapping(bytes32 => PendingCommitteeData) data;
}

struct PendingCommitteeData {
    bytes32 aggregatedKey; // agregated key provided by the member
    bool inCommittee;
}

interface ICommitteeRegistry {
    function registerMember(
        bytes32 _publicKey,
        StreamDenomination[] memory requestedStreams,
        Role[] memory requestedRoles
    ) external;

    function registerCommittee(uint256 _committeeId, Committee calldata _committee) external;

    function getCommittee(uint256 _committeeId) external view returns (Committee calldata);

    function getCommitteeMembers(uint256 _committeeId) external view returns (CommitteeMember[] memory);

    function getMemberPubKeyByIndex(uint16 _memberIndex) external view returns (bytes32);

    function getMemberIndexByAddress(address _address) external view returns (uint16);

    // function selectCommittee(uint64) external view returns (bytes32);

    // Errors
    error MemberNotRegistered(address memberAddress);
    error MemberIndexNotFound(uint16 memberIndex);
    // /// @notice Select a committee for a stream
    // /// @param _streamId The stream id to select a committee for
    // /// @dev This function is called when a new packet is created
    // /// @return The committee public key for the stream
    // function selectCommittee(uint64 _streamId) external view returns (bytes32);

    /// @notice Create a new committee for a stream
    /// @param _streamId The stream id to create a new committee for
    /// @dev This function is called when the slot usage threshold is reached
    /// TODO: This function should choose committee members based on the stream id/denomination
    /// once the committee is ready, it should be registered with the registerCommittee function
    function createNewCommittee(uint64 _streamId) external;

    /// @notice Return true if there is a pending committee for the stream and it's expired
    /// @param _streamId The stream id to check for a pending committee
    function isPendingCommitteeExpired(uint64 _streamId) external view returns (bool);

    function setPegManager(IPegManager _pegManager) external;

    /// ===================== Events =========================
    event NewCommittee(uint256 indexed committeeId, Committee _committee);
    event NewMember(bytes32 indexed publicKey, StreamDenomination[] requestedStreams, Role[] requestedRoles);
    event NewPendingCommittee(uint256 indexed streamId, Committee _committee);

    /// ==================== Errors =====================
    error RequestedDifferentStreamsAndRolesLength(uint256 streamsLength, uint256 rolesLength);
    error RequestedNoRoles();
    error RequestedNoneRoleForStream(StreamDenomination stream);
    error RequestedMultipleRolesForStream(StreamDenomination stream, Role role1, Role role2);
    error AlreadyRegisteredMember(bytes32 memberPubKey);
    error NonRegisteredMember(uint16 memberIndex);
    error TooManyMembers(uint256 maxMemebers);
    error TooManyMembersPerComitee(uint256 maxMemebersPerCommittee);
    error TooManyCommittees(uint256 maxCommitteeSize);
    error AlreadyRegisteredCommittee(uint256 committeeId);
    error MemberNotFound(address memberAddress);
    error CommitteeIsNotPending(uint64 streamId);
    error InvalidAgregatedKey();
    error InvalidHashDrp();
    error NoCommitteeMembers();
    error PendingCommitteeTimelockNotExpired(uint256 expireAt, uint256 currentTime);
    error MemberNotInCommittee(bytes32);
    error MemberAlreadyUpdated(bytes32);

    // Unified this error in some file
    error UnauthorizedAccount(address account);
    error InvalidZeroAddress();
}
