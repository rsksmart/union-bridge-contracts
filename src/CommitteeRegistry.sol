// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {Committee, ICommitteeRegistry} from "./interfaces/ICommitteeRegistry.sol";

contract CommitteeRegistry is ICommitteeRegistry, Initializable {
    uint256 public constant MAX_COMITTEE_SIZE = 100;
    uint256 public constant MAX_MEMBERS_SIZE = 100;
    bytes32[] internal committees;
    // Committee key => Comittee
    mapping(bytes32 => Committee) internal committeesByKey;
    // Committee key => members addresses
    mapping(bytes32 => address[]) internal membersByCommitee;

    event newCommittee(bytes32 indexed committeeKey, Committee committee, address[] _members);

    error tooManyMembers(uint256 maxMemebersSize);
    error tooManyCommittees(uint256 maxComitteeSize);
    error alreadyRegisteredCommittee(bytes32 committeeLey);

    function initialize() public initializer {}

    function registerCommittee(Committee calldata _committee, address[] calldata _members) external {
        // Check if exists
        if (committeesByKey[_committee.internalKey].internalKey != bytes32(0)) {
            revert alreadyRegisteredCommittee(_committee.internalKey);
        }
        // Check max
        if (committees.length >= MAX_COMITTEE_SIZE) {
            revert tooManyCommittees(MAX_COMITTEE_SIZE);
        }
        // Set up Committee
        committees.push(_committee.internalKey);
        committeesByKey[_committee.internalKey] = _committee;

        // Set up Members
        if (_members.length > MAX_MEMBERS_SIZE) {
            revert tooManyMembers(MAX_MEMBERS_SIZE);
        }
        // Set up memebers
        membersByCommitee[_committee.internalKey] = _members;
        emit newCommittee(_committee.internalKey, _committee, _members);
    }

    function getCommitteeByIndex(uint256 _committeeIndex) external view returns (bytes32) {
        return committees[_committeeIndex];
    }

    function getCommitteesLength() external view returns (uint256) {
        return committees.length;
    }

    function getCommittee(bytes32 _committeeKey) external view returns (Committee memory) {
        return committeesByKey[_committeeKey];
    }

    function getCommitteeMembers(bytes32 _committeeKey) external view returns (address[] memory) {
        return membersByCommitee[_committeeKey];
    }

    function getNextAvailableCommittee() external view returns (Committee memory) {
        // For now, always return the first committee
        return committeesByKey[committees[0]];
    }
}
