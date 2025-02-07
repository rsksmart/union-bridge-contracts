// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {Role, Member, Committee, ICommitteeRegistry} from "./interfaces/ICommitteeRegistry.sol";

contract CommitteeRegistry is ICommitteeRegistry, Initializable {
    uint256 public constant MAX_COMMITTEES_SIZE = 100;
    uint256 public constant MAX_MEMBERS_SIZE = 1000;
    uint256 public constant MAX_MEMBERS_PER_COMMITTEE = 100;
    Member[] internal members;
    bytes32[] internal committees;
    // Committee key => Committee
    mapping(bytes32 => Committee) internal committeesByKey;

    event newCommittee(Committee _committee);
    event newMember(bytes32 _publicKey, Role _role);

    error alreadyRegisteredMember(bytes32 memberLey);
    error nonRegisteredMember(uint8 memberLey);
    error tooManyMembers(uint256 maxMemebers);
    error tooManyMembersPerComitee(uint256 maxMemebersPerCommittee);
    error tooManyCommittees(uint256 maxCommitteeSize);
    error alreadyRegisteredCommittee(bytes32 committeeLey);

    function initialize() public initializer {}

    function registerMember(bytes32 _publicKey, Role _role) external {
        // Check max Members
        if (members.length >= MAX_MEMBERS_SIZE) {
            revert tooManyMembers(MAX_MEMBERS_SIZE);
        }

        //Check if exists
        for (uint256 i = 0; i < members.length; i++) {
            if (members[i].publicKey == _publicKey && members[i].role == _role) {
                revert alreadyRegisteredMember(_publicKey);
            }
        }

        members.push(); // Expand the array
        Member storage m = members[members.length - 1]; // Get reference
        m.publicKey = _publicKey;
        m.role = _role;

        emit newMember(_publicKey, _role);
    }

    function registerCommittee(Committee calldata _committee) external {
        // Check if exists
        if (committeesByKey[_committee.internalKey].internalKey != bytes32(0)) {
            revert alreadyRegisteredCommittee(_committee.internalKey);
        }
        // Check max Committees
        if (committees.length >= MAX_COMMITTEES_SIZE) {
            revert tooManyCommittees(MAX_COMMITTEES_SIZE);
        }
        // Check max Members for the committee
        if (_committee.memberIndices.length > MAX_MEMBERS_PER_COMMITTEE) {
            revert tooManyMembersPerComitee(MAX_MEMBERS_PER_COMMITTEE);
        }
        // Check if all members are registered
        for (uint256 i = 0; i < _committee.memberIndices.length; i++) {
            if (_committee.memberIndices[i] >= members.length) {
                revert nonRegisteredMember(_committee.memberIndices[i]);
            }
        }
        // Set up Committee
        committees.push(_committee.internalKey);
        committeesByKey[_committee.internalKey] = _committee;
        emit newCommittee(_committee);
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

    function getCommitteeMemberIndices(bytes32 _committeeKey) external view returns (uint8[] memory) {
        return committeesByKey[_committeeKey].memberIndices;
    }

    function getNextAvailableCommittee() external view returns (Committee memory) {
        // For now, always return the first committee
        return committeesByKey[committees[0]];
    }
}
