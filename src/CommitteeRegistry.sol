// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import "forge-std/console.sol";

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

    // Committee selection constants
    uint256 public constant MIN_WATCHTOWERS = 3;
    uint256 public constant MIN_OPERATORS = 3;
    uint256 public constant MIN_COMMITTEE_MEMBERS = 10;

    Member[] internal members;
    bytes32[] internal committees;
    // Committee key => Committee
    mapping(bytes32 => Committee) internal committeesByKey;
    mapping(address => uint16) internal memberIndexByAddress;
    mapping(StreamDenomination denomination => CommitteeMember[]) internal committeesCandidates;

    event newCommittee(bytes32 indexed internalKey, Committee _committee);
    event newMember(bytes32 indexed publicKey, StreamDenomination[] requestedStreams, Role[] requestedRoles);

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
            revert TooManyMembers(MAX_MEMBERS_SIZE);
        }

        // console.log("registerMember:");
        // console.log("msg.sender");
        // console.logAddress(msg.sender);
        // console.log("publicKey");
        // console.logBytes32(_publicKey);

        // Check if exists
        if (memberIndexByAddress[msg.sender] != 0) {
            revert AlreadyRegisteredMember(getMemberPubKeyByAddress(msg.sender));
        }

        // Check if the roles and streams are the same length
        if (requestedStreams.length != requestedRoles.length) {
            revert RequestedDifferentStreamsAndRolesLength(requestedStreams.length, requestedRoles.length);
        }

        // Check at least one role requested
        if (requestedRoles.length == 0) {
            revert RequestedNoRoles();
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
                revert RequestedNoneRoleForStream(requestedStreams[i]);
            }
            if (m.requestedRoles[requestedStreams[i]] != Role.None) {
                revert RequestedMultipleRolesForStream(
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
            revert AlreadyRegisteredCommittee(_committee.internalKey);
        }
        // Check max Committees
        if (committees.length >= MAX_COMMITTEES_SIZE) {
            revert TooManyCommittees(MAX_COMMITTEES_SIZE);
        }
        // Check max Members for the committee
        if (_committee.memberIndexesAndRoles.length > MAX_MEMBERS_PER_COMMITTEE) {
            revert TooManyMembersPerCommittee(MAX_MEMBERS_PER_COMMITTEE);
        }
        // Check if all members are registered
        for (uint256 i = 0; i < _committee.memberIndexesAndRoles.length; i++) {
            if (_committee.memberIndexesAndRoles[i].index >= members.length) {
                revert NonRegisteredMember(_committee.memberIndexesAndRoles[i].index);
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

    function getMembersLength() external view returns (uint256) {
        return members.length;
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
        bytes32 publicKey = members[_memberIndex].publicKey;
        if (publicKey == "") {
            revert MemberIndexNotFound(_memberIndex);
        }
        return publicKey;
    }

    function getMemberIndexByAddress(address _address) external view returns (uint16) {
        uint16 memberIndex = memberIndexByAddress[_address];

        // 0 is reserved for non registered members
        if (memberIndex == 0) {
            revert MemberNotRegistered(_address);
        }

        // Substract 1 to get the correct index
        return memberIndex - 1;
    }

    function getMemberPubKeyByAddress(address _address) public view returns (bytes32) {
        uint16 memberIndex = memberIndexByAddress[_address];

        // 0 is reserved for non registered members
        if (memberIndex == 0) {
            return 0x00;
        }

        // Substract 1 to get the correct index
        return members[memberIndex - 1].publicKey;
    }

    function createCommittee(uint64 _streamId) external view returns (bytes32) {
        // For now, just return the first committee key for backwards compatibility with existing tests.
        return committees[0];
    }

    /**
     * @notice Randomly selects members to form a new committee for a given stream
     * @dev Pseudo-randomly select at least MIN_WATCHTOWERS watchtowers and MIN_OPERATORS operators.
     * - reverts with notEnoughWatchtowers if there are fewer than MIN_WATCHTOWERS watchtower candidates
     * - reverts with notEnoughOperators if there are fewer than MIN_OPERATORS operator candidates
     *
     * @param _streamId The ID of the stream to select committee members for (0-4)
     * @return An array of MIN_COMMITTEE_MEMBERS CommitteeMembers containing the selected members.
     *
     */
    function selectCommittee(uint64 _streamId) external view returns (CommitteeMember[] memory) {
        // Get the stream denomination for the streamId
        StreamDenomination denomination = StreamDenomination(_streamId);

        // Get all candidates for this denomination
        CommitteeMember[] memory candidates = committeesCandidates[denomination];
        uint256 candidatesLength = candidates.length;

        // Separate watchtowers and operators
        uint256[] memory watchtowerIndices = new uint256[](candidatesLength);
        uint256[] memory operatorIndices = new uint256[](candidatesLength);
        uint256 watchtowerCount = 0;
        uint256 operatorCount = 0;

        for (uint256 i = 0; i < candidatesLength; i++) {
            if (candidates[i].role == Role.Watchtower) {
                watchtowerIndices[watchtowerCount] = i;
                watchtowerCount++;
            } else if (candidates[i].role == Role.Operator) {
                operatorIndices[operatorCount] = i;
                operatorCount++;
            }
        }

        // Ensure we have enough candidates
        if (watchtowerCount < MIN_WATCHTOWERS) {
            revert NotEnoughWatchtowers(MIN_WATCHTOWERS, watchtowerCount);
        }
        if (operatorCount < MIN_OPERATORS) {
            revert NotEnoughOperators(MIN_OPERATORS, operatorCount);
        }

        // Check if we have enough total members for the committee
        uint256 totalAvailableMembers = watchtowerCount + operatorCount;
        if (totalAvailableMembers < MIN_COMMITTEE_MEMBERS) {
            revert NotEnoughMembers(MIN_COMMITTEE_MEMBERS, totalAvailableMembers);
        }

        // True randomness is not required here. We only need enough unpredictability to ensure
        // different committee members get selected across multiple runs.
        // We use Fisher-Yates shuffle because it guarantees each index is selected exactly once.
        // This way we avoid index collisions and infinite loops.

        // Shuffle watchtowers
        for (uint256 i = watchtowerCount - 1; i > 0; i--) {
            uint256 j = uint256(keccak256(abi.encodePacked(block.timestamp, "watchtower", i))) % (i + 1);
            uint256 temp = watchtowerIndices[i];
            watchtowerIndices[i] = watchtowerIndices[j];
            watchtowerIndices[j] = temp;
        }

        // Shuffle operators
        for (uint256 i = operatorCount - 1; i > 0; i--) {
            uint256 j = uint256(keccak256(abi.encodePacked(block.timestamp, "operator", i))) % (i + 1);
            uint256 temp = operatorIndices[i];
            operatorIndices[i] = operatorIndices[j];
            operatorIndices[j] = temp;
        }

        // Create the final committee with MIN_COMMITTEE_MEMBERS members
        CommitteeMember[] memory selectedMembers = new CommitteeMember[](MIN_COMMITTEE_MEMBERS);

        // Take MIN_WATCHTOWERS watchtowers using indices
        for (uint256 i = 0; i < MIN_WATCHTOWERS; i++) {
            selectedMembers[i] = candidates[watchtowerIndices[i]];
        }

        // Calculate remaining slots for operators
        uint256 remainingSlots = MIN_COMMITTEE_MEMBERS - MIN_WATCHTOWERS;

        // Take operators for remaining slots (should be at least MIN_OPERATORS)
        for (uint256 i = 0; i < remainingSlots; i++) {
            selectedMembers[i + MIN_WATCHTOWERS] = candidates[operatorIndices[i]];
        }

        return selectedMembers;
    }

    function addCommitteeCandidate(StreamDenomination _denomination, CommitteeMember memory _member) external {
        // In a real implementation, this would have access control
        // but for testing purposes, we'll allow any caller
        committeesCandidates[_denomination].push(_member);
    }

    function getCommitteeCandidates(StreamDenomination _denomination)
        external
        view
        returns (CommitteeMember[] memory)
    {
        return committeesCandidates[_denomination];
    }
}
