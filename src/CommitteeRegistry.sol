// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {BaseProxy} from "./BaseProxy.sol";
import {
    Role,
    Member,
    CommitteeMember,
    Committee,
    ICommitteeRegistry,
    PendingCommittee,
    PendingCommitteeData
} from "./interfaces/ICommitteeRegistry.sol";
import {StreamDenomination, IStreamManager} from "./interfaces/IStreamManager.sol";
import {IPegManager} from "./interfaces/IPegManager.sol";
import {SecurityBond} from "./SecurityBond.sol";

contract CommitteeRegistry is ICommitteeRegistry, SecurityBond, BaseProxy {
    uint256 public constant MAX_COMMITTEES_SIZE = 100;
    uint256 public constant MAX_MEMBERS_SIZE = 256;
    uint256 public constant MAX_MEMBERS_PER_COMMITTEE = 100;
    Member[] internal members;
    mapping(uint64 => PendingCommittee) internal pendingCommittees;
    mapping(uint256 => Committee) internal committeesByKey;
    mapping(address => uint16) internal memberIndexByAddress;
    address pegManager;

    uint256 public constant pendingCommitteeTimelock = 1 days;

    error CommitteeAlreadyRegistered(uint256 committeeId);

    function initialize(address _initialOwner) public initializer {
        __BaseProxy_init(_initialOwner);
    }

    // FIXME: Temporary function to register a committee, should be deleted when createNewCommittee is called in setup
    function registerCommittee(uint256 _committeeId, Committee calldata _committee) external {
        if (committeesByKey[_committeeId].memberIndexesAndRoles.length != 0) {
            revert CommitteeAlreadyRegistered(_committeeId);
        }
        committeesByKey[_committeeId].aggregatedKey = _committee.aggregatedKey;
        for (uint256 i = 0; i < _committee.memberIndexesAndRoles.length; i++) {
            committeesByKey[_committeeId].memberIndexesAndRoles.push(_committee.memberIndexesAndRoles[i]);
        }
        committeesByKey[_committeeId].leaderIndex = _committee.leaderIndex;

        emit NewCommittee(_committeeId, _committee);
    }

    function _getMemberPubKeyByAddress(address _address) public view returns (bytes32) {
        uint16 memberIndex = memberIndexByAddress[_address];
        if (memberIndex == 0) {
            return bytes32(0);
        }
        // Substract 1 to get the correct index
        return members[memberIndex - 1].publicKey;
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

        if (_getMemberPubKeyByAddress(msg.sender) != bytes32(0)) {
            revert AlreadyRegisteredMember(_publicKey);
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
        // We save the position in the array + 1, to avoid 0 as a valid index, it is then substracted in _getMemberPubKeyByAddress
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

        emit NewMember(_publicKey, requestedStreams, requestedRoles);
    }

    function _registerCommittee(uint256 _committeeId, Committee storage _committee) internal {
        // Check if exists
        // NOTE: Could we ignore this check due to committeeId being unique?
        if (committeesByKey[_committeeId].aggregatedKey != bytes32(0)) {
            return;
        }

        committeesByKey[_committeeId] = _committee;
        emit NewCommittee(_committeeId, _committee);
    }

    function getCommittee(uint256 _committeeId) external view returns (Committee memory) {
        return committeesByKey[_committeeId];
    }

    function getCommitteeMembers(uint256 _committeeId) external view returns (CommitteeMember[] memory) {
        return committeesByKey[_committeeId].memberIndexesAndRoles;
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
        if (memberIndex == 0 || memberIndex > members.length) {
            revert MemberNotRegistered(_address);
        }

        // Substract 1 to get the correct index
        return memberIndex - 1;
    }

    function createNewCommittee(uint64 _streamId) external onlyPegManager {
        // TODO: Validate if the streamId is valid
        // TODO: Validate who can call this function. PegManager and external or in setup.
        // If it's called externally we should check that we really need to create a new committee.
        // Or maybe validate that there is a pending committee that it's expired

        PendingCommittee storage pendingCommittee = pendingCommittees[_streamId];
        if (pendingCommittee.expireAt != 0) {
            if (block.timestamp < pendingCommittee.expireAt) {
                // This is called from the pegManager, so we should not revert.
                return;
            }

            _slashCommittee();
            _deletePendingCommittee(_streamId);
        }
        _createNewCommittee(_streamId);
    }

    function _createNewCommittee(uint64 _streamId) internal returns (bool) {
        CommitteeMember[] memory committeeMembers = getCommitteeMembersForStream(_streamId);
        if (committeeMembers.length == 0) {
            // This is called from the pegManager, so we should not revert.
            return false;
        }

        pendingCommittees[_streamId].expireAt = block.timestamp + pendingCommitteeTimelock;
        pendingCommittees[_streamId].missingData = uint16(committeeMembers.length);

        // Initialize the committee members here.
        // No need to initialize aggregatedKey, since it will be set by the members.
        for (uint256 i = 0; i < committeeMembers.length; i++) {
            // Copy committee members from memory to storage
            pendingCommittees[_streamId].committee.memberIndexesAndRoles.push(committeeMembers[i]);

            bytes32 memberPubKey = members[committeeMembers[i].index].publicKey;
            // Initialize committee users pending data
            pendingCommittees[_streamId].data[memberPubKey] =
                PendingCommitteeData({inCommittee: true, aggregatedKey: bytes32(0)});
        }
        emit NewPendingCommittee(_streamId, pendingCommittees[_streamId].committee);
        return true;
    }

    function depositMemberInfoForCommittee(uint64 _streamId, bytes32 _aggregatedKey) external {
        PendingCommittee storage pendingCommittee = pendingCommittees[_streamId];
        if (pendingCommittee.expireAt == 0) {
            revert CommitteeIsNotPending(_streamId);
        }

        if (_aggregatedKey == bytes32(0)) {
            revert InvalidAgregatedKey();
        }

        bytes32 memberPubKey = _getMemberPubKey();
        if (pendingCommittee.data[memberPubKey].inCommittee == false) {
            revert MemberNotInCommittee(memberPubKey);
        }

        if (pendingCommittee.data[memberPubKey].aggregatedKey != bytes32(0)) {
            revert MemberAlreadyUpdated(memberPubKey);
        }

        pendingCommittee.data[memberPubKey].aggregatedKey = _aggregatedKey;

        if (pendingCommittee.committee.aggregatedKey == bytes32(0)) {
            // Save the agregated key for the committee
            pendingCommittee.committee.aggregatedKey = _aggregatedKey;
        } else {
            if (pendingCommittee.committee.aggregatedKey != _aggregatedKey) {
                _deletePendingCommittee(_streamId);
                _createNewCommittee(_streamId); // Ignoring checks
                return;
            }
        }

        pendingCommittee.missingData--;
        if (pendingCommittee.missingData != 0) {
            // Committee is not completed yet
            return;
        }

        // Create unique committee id associated to the streamId and packetNumber.
        uint256 committeeId = uint256(keccak256(abi.encode(_streamId, streamManager.getPacketsLength(_streamId))));
        _registerCommittee(committeeId, pendingCommittee.committee);
        // create new packet
        streamManager.createNewPacket(_streamId, committeeId, pendingCommittee.committee.aggregatedKey);
        _deletePendingCommittee(_streamId);
    }

    function _slashCommittee() internal {
        // TODO: slash the members. Sasasaaa.
    }

    function getCommitteeMembersForStream(uint64 _streamId) internal pure returns (CommitteeMember[] memory) {
        // WIP: This is being implemented by Agustin
        CommitteeMember[] memory committeeMembers = new CommitteeMember[](2);
        committeeMembers[0] = CommitteeMember({index: 0, role: Role.Operator});
        committeeMembers[1] = CommitteeMember({index: 1, role: Role.Watchtower});
        return committeeMembers;
    }

    function _getMemberPubKey() internal view returns (bytes32) {
        bytes32 memberPubKey = _getMemberPubKeyByAddress(msg.sender);
        if (memberPubKey == bytes32(0)) {
            revert MemberNotFound(msg.sender);
        }
        return memberPubKey;
    }

    function isPendingCommitteeExpired(uint64 _streamId) external view returns (bool) {
        // If no pending committee in proccess we return false
        if (pendingCommittees[_streamId].expireAt == 0) {
            return false;
        }
        return block.timestamp > pendingCommittees[_streamId].expireAt;
    }

    function _deletePendingCommittee(uint64 _streamId) internal {
        CommitteeMember[] storage committeeMembers = pendingCommittees[_streamId].committee.memberIndexesAndRoles;
        for (uint256 i = 0; i < committeeMembers.length; i++) {
            bytes32 memberPubKey = members[committeeMembers[i].index].publicKey;
            delete pendingCommittees[_streamId].data[memberPubKey];
        }
        delete pendingCommittees[_streamId];
    }

    function setPegManager(IPegManager _pegManager) external onlyOwner {
        if (address(_pegManager) == address(0)) {
            revert InvalidZeroAddress();
        }
        pegManager = address(_pegManager);
    }

    modifier onlyPegManager() {
        _checkPegManager();
        _;
    }

    /**
     * @dev Throws if the sender is not the pegManager.
     */
    function _checkPegManager() internal view virtual {
        if (pegManager != msg.sender) {
            revert UnauthorizedAccount(msg.sender);
        }
    }
}
