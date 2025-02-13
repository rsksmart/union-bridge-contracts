// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {BaseProxy} from "./BaseProxy.sol";
import {Role, Member, CommitteeMember, Committee, ICommitteeRegistry} from "./interfaces/ICommitteeRegistry.sol";
import {StreamDenomination} from "./interfaces/IStreamManager.sol";

contract CommitteeRegistry is ICommitteeRegistry, Initializable, BaseProxy {
    uint256 public constant MAX_COMMITTEES_SIZE = 100;
    uint256 public constant MAX_MEMBERS_SIZE = 256;
    uint256 public constant MAX_MEMBERS_PER_COMMITTEE = 100;
    Member[] internal members;
    bytes32[] internal committees;
    // Committee key => Committee
    mapping(bytes32 => Committee) internal committeesByKey;

    event newCommittee(bytes32 indexed internalKey, Committee _committee);
    event newMember(bytes32 indexed publicKey, StreamDenomination[] requestedStreams, Role[] requestedRoles);

    error requestedDifferentStreamsAndRolesLength(uint256 streamsLength, uint256 rolesLength);
    error requestedNoRoles();
    error requestedNoneRoleForStream(StreamDenomination stream);
    error requestedMultipleRolesForStream(StreamDenomination stream, Role role1, Role role2);
    error alreadyRegisteredMember(bytes32 memberPubKey);
    error nonRegisteredMember(uint16 memberIndex);
    error tooManyMembers(uint256 maxMemebers);
    error tooManyMembersPerComitee(uint256 maxMemebersPerCommittee);
    error tooManyCommittees(uint256 maxCommitteeSize);
    error alreadyRegisteredCommittee(bytes32 committeeLey);

    function initialize(address _initialOwner) public initializer {
        __BaseProxy_init(_initialOwner);
    }

    function registerMember(
        bytes32 _publicKey,
        StreamDenomination[] calldata requestedStreams,
        Role[] calldata requestedRoles
    ) public {
        // Check max Members
        if (members.length >= MAX_MEMBERS_SIZE) {
            revert tooManyMembers(MAX_MEMBERS_SIZE);
        }

        // Check if exists
        uint256 memberLength = members.length;
        for (uint256 i = 0; i < memberLength; i++) {
            if (members[i].publicKey == _publicKey) {
                revert alreadyRegisteredMember(_publicKey);
            }
        }

        // Check if the roles and streams are the same length
        if (requestedStreams.length != requestedRoles.length) {
            revert requestedDifferentStreamsAndRolesLength(requestedStreams.length, requestedRoles.length);
        }

        // Check at least one role requested
        if (requestedRoles.length == 0) {
            revert requestedNoRoles();
        }

        members.push(); // Expand the array
        Member storage m = members[members.length - 1]; // Get reference
        m.publicKey = _publicKey;

        // Set requested roles
        for (uint256 i = 0; i < requestedStreams.length; i++) {
            if (requestedRoles[i] == Role.None) {
                revert requestedNoneRoleForStream(requestedStreams[i]);
            }
            if (m.requestedRoles[requestedStreams[i]] != Role.None) {
                revert requestedMultipleRolesForStream(
                    requestedStreams[i], m.requestedRoles[requestedStreams[i]], requestedRoles[i]
                );
            }
            m.requestedRoles[requestedStreams[i]] = requestedRoles[i];
        }

        emit newMember(_publicKey, requestedStreams, requestedRoles);
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
        if (_committee.memberIndexesAndRoles.length > MAX_MEMBERS_PER_COMMITTEE) {
            revert tooManyMembersPerComitee(MAX_MEMBERS_PER_COMMITTEE);
        }
        // Check if all members are registered
        for (uint256 i = 0; i < _committee.memberIndexesAndRoles.length; i++) {
            if (_committee.memberIndexesAndRoles[i].index >= members.length) {
                revert nonRegisteredMember(_committee.memberIndexesAndRoles[i].index);
            }
        }
        // Set up Committee
        committees.push(_committee.internalKey);
        committeesByKey[_committee.internalKey] = _committee;
        emit newCommittee(_committee.internalKey, _committee);
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

    function getCommitteememberIndexesAndRoles(bytes32 _committeeKey)
        external
        view
        returns (CommitteeMember[] memory)
    {
        return committeesByKey[_committeeKey].memberIndexesAndRoles;
    }

    function getNextAvailableCommittee() external view returns (Committee memory) {
        // For now, always return the first committee
        return committeesByKey[committees[0]];
    }
}
