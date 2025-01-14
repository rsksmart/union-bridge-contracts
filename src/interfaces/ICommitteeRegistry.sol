// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

struct Committee {
    bytes32 internalKey; // BTC public key of the commitee
    address leader; // TODO add leader logic
    address backupLeader; // TODO add backup logic
}

interface ICommitteeRegistry {
    function registerCommittee(Committee calldata _committee, address[] memory _members) external;

    function getCommittee(bytes32 _committeeKey) external view returns (Committee calldata);

    function getCommitteeMembers(bytes32 _committeeKey) external view returns (address[] calldata);

    function getCommitteeByIndex(uint256 _committeeIndex) external view returns (bytes32);

    function getCommitteesLength() external view returns (uint256);

    function getNextAvailableCommittee() external view returns (Committee calldata);
}
