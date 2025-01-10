// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.19;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {Committee, ICommitteeRegistry} from "./interfaces/ICommitteeRegistry.sol";

contract CommitteeRegistry is ICommitteeRegistry, Initializable {
    mapping(uint256 => Committee) private committees;
    uint256 public committeeCount = 0;

    function initialize() public initializer {
        committeeCount = 0;
    }

    function registerCommittee(address[2] memory _members, bytes32 _committeeKey) external returns (uint256) {
        uint256 committeeId = committeeCount;
        committees[committeeId] = Committee(_members, _committeeKey);
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
