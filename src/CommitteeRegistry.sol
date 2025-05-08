// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {BaseProxy} from "./BaseProxy.sol";
import {Role, Member, CommitteeMember, Committee, ICommitteeRegistry} from "./interfaces/ICommitteeRegistry.sol";
import {StreamDenomination, IStreamManager} from "./interfaces/IStreamManager.sol";
import {SecurityBond} from "./SecurityBond.sol";

contract CommitteeRegistry is ICommitteeRegistry, SecurityBond, BaseProxy {
    uint256 public constant MAX_COMMITTEES_SIZE = 100;
    uint256 public constant MAX_MEMBERS_SIZE = 256;
    uint256 public constant MAX_MEMBERS_PER_COMMITTEE = 100;
    Member[] internal members;
    bytes32[] internal committees;
    // Committee key => Committee
    mapping(bytes32 => Committee) internal committeesByKey;
    mapping(address => uint16) internal memberIndexByAddress;

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
    ) external {
        // Check max Members
        if (members.length >= MAX_MEMBERS_SIZE) {
            revert tooManyMembers(MAX_MEMBERS_SIZE);
        }

        // TODO: this cold be checked using the address-to-index mapping
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

        // TODO: check if we need to ask for the uncompressed public key and check it against the sender address
        members.push(); // Expand the array
        Member storage m = members[members.length - 1]; // Get reference
        m.publicKey = _publicKey;
        // We save the position in the array + 1, to avoid 0 as a valid index, it is then substracted in getMemberPubKeyByAddress
        memberIndexByAddress[msg.sender] = uint16(members.length);

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

    function getCommitteeMember(bytes32 _committeeKey) external view returns (CommitteeMember[] memory) {
        return committeesByKey[_committeeKey].memberIndexesAndRoles;
    }

    function getNextAvailableCommittee() external view returns (Committee memory) {
        // For now, always return the first committee
        return committeesByKey[committees[0]];
    }

    function getMemberPubKeyByIndex(uint16 _memberIndex) external view returns (bytes32) {
        //TODO: check if needed
        return members[_memberIndex].publicKey;
    }

    function getMemberPubKeyByAddress(address _address) external view returns (bytes32) {
        uint16 memberIndex = memberIndexByAddress[_address];

        // 0 is reserved for non registered members
        if (memberIndex == 0) {
            return 0x00;
        }

        // Substract 1 to get the correct index
        return members[memberIndex - 1].publicKey;
    }
}
