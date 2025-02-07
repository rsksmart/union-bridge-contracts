// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

enum Role {
    Operator,
    Watchtower
}

struct Member {
    bytes32 publicKey;
    Role role;
    mapping(string => string) data;
}

struct Committee {
    bytes32 internalKey; // BTC public key of the commitee
    uint8[] memberIndices; // Indexes of the members in the members array
    uint8 leaderIndex; // TODO add leader logic
}

interface ICommitteeRegistry {
    function registerMember(bytes32 _publicKey, Role _role) external;

    function registerCommittee(Committee calldata _committee) external;

    function getCommittee(bytes32 _committeeKey) external view returns (Committee calldata);

    function getCommitteeMemberIndices(bytes32 _committeeKey) external view returns (uint8[] calldata);

    function getCommitteeByIndex(uint256 _committeeIndex) external view returns (bytes32);

    function getCommitteesLength() external view returns (uint256);

    function getNextAvailableCommittee() external view returns (Committee calldata);
}
