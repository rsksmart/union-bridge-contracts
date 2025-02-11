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
    uint16 index;
    Role role;
}

struct Committee {
    bytes32 internalKey; // BTC public key of the commitee
    CommitteeMember[] memberIndexesAndRoles; // Indices and roles of the members from the members array
    uint8 leaderIndex; // TODO add leader logic
}

interface ICommitteeRegistry {
    function registerMember(
        bytes32 _publicKey,
        StreamDenomination[] memory requestedStreams,
        Role[] memory requestedRoles
    ) external;

    function registerCommittee(Committee calldata _committee) external;

    function getCommittee(bytes32 _committeeKey) external view returns (Committee calldata);

    function getCommitteememberIndexesAndRoles(bytes32 _committeeKey)
        external
        view
        returns (CommitteeMember[] memory);

    function getCommitteeByIndex(uint256 _committeeIndex) external view returns (bytes32);

    function getCommitteesLength() external view returns (uint256);

    function getNextAvailableCommittee() external view returns (Committee calldata);
}
