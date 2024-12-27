// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.19;

struct Committee {
    address[2] members;
    bytes32 internalKey;
}

contract CommitteeRegistry {
    mapping(uint256 => Committee) private committees;
    uint256 public committeeCount;

    constructor() {
        committeeCount = 0;
    }

    function registerCommittee(address[2] memory members, bytes32 committeeKey) external returns (uint256) {
        uint256 committeeId = committeeCount;
        committees[committeeId] = Committee(members, committeeKey);
        committeeCount++;
        return committeeId;
    }

    function getCommittee(uint256 committeeId) external view returns (address[2] memory) {
        return committees[committeeId].members;
    }

    function getNextAvailableCommittee() external view returns (uint256, Committee memory) {
        // For now, always return the first committee
        uint256 committeeId = 0;
        return (committeeId, committees[committeeId]);
    }
}
