// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.19;

struct Committee {
    address[2] members;
    bytes32 internalKey;
}

interface ICommitteeRegistry {
    function registerCommittee(address[2] memory members, bytes32 committeeKey) external returns (uint256);

    function getCommittee(uint256 committeeId) external view returns (address[2] memory);

    function getNextAvailableCommittee() external view returns (uint256, Committee memory);
}
