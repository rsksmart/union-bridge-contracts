// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {StreamDenomination} from "./IStreamManager.sol";

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
    bytes32 internalKey; // BTC public key of the commitee
    CommitteeMember[] memberIndexesAndRoles; // Indices and roles of the members from the members array
    uint8 leaderIndex; // TODO add leader logic
}

interface ICommitteeRegistry {
    error RequestedDifferentStreamsAndRolesLength(uint256 streamsLength, uint256 rolesLength);
    error RequestedNoRoles();
    error RequestedNoneRoleForStream(StreamDenomination stream);
    error RequestedMultipleRolesForStream(StreamDenomination stream, Role role1, Role role2);
    error AlreadyRegisteredMember(bytes32 memberPubKey);
    error NonRegisteredMember(uint16 memberIndex);
    error TooManyMembers(uint256 maxMembers);
    error TooManyMembersPerCommittee(uint256 maxMembersPerCommittee);
    error TooManyCommittees(uint256 maxCommitteeSize);
    error AlreadyRegisteredCommittee(bytes32 committeeKey);
    error NotEnoughWatchtowers(uint256 required, uint256 available);
    error NotEnoughOperators(uint256 required, uint256 available);
    error NotEnoughMembers(uint256 required, uint256 available);

    function registerMember(
        bytes32 _publicKey,
        StreamDenomination[] memory requestedStreams,
        Role[] memory requestedRoles
    ) external;

    function registerCommittee(Committee calldata _committee) external;

    function getCommittee(bytes32 _committeeKey) external view returns (Committee calldata);

    function getCommitteeMember(bytes32 _committeeKey) external view returns (CommitteeMember[] memory);

    function getCommitteeByIndex(uint256 _committeeIndex) external view returns (bytes32);

    function getCommitteesLength() external view returns (uint256);

    function getNextAvailableCommittee() external view returns (Committee calldata);

    function getMemberPubKeyByIndex(uint16 _memberIndex) external view returns (bytes32);

    function getMemberIndexByAddress(address _address) external view returns (uint16);

    function createCommittee(uint64 _streamId) external view returns (bytes32);

    function selectCommittee(uint64 _streamId) external view returns (CommitteeMember[] memory);

    function addCommitteeCandidate(StreamDenomination _denomination, CommitteeMember memory _member) external;

    function getCommitteeCandidates(StreamDenomination _denomination)
        external
        view
        returns (CommitteeMember[] memory);
}
