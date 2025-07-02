// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {CommitteeRegistry, CommitteeMember, PublicKeyRegistration} from "src/CommitteeRegistry.sol";
import {Role} from "src/interfaces/ICommitteeRegistry.sol";
import {StreamDenomination} from "src/interfaces/IStreamManager.sol";
import {PendingCommitteeStatus, PendingCommitteeData} from "src/interfaces/ICommitteeRegistry.sol";

/// @notice Wrapper for testing CommitteeRegistry
contract CommitteeRegistryHarness is CommitteeRegistry {
    function initialize(address _initialOwner) public override initializer {
        CommitteeRegistry.initialize(_initialOwner);
    }

    function selectCommittee(uint64 _denomination) public returns (CommitteeMember[] memory, PendingCommitteeStatus) {
        return _selectCommittee(_denomination);
    }

    function registerCandidateToStreamHarness(
        address _memberAddress,
        StreamDenomination _stream,
        Role _role,
        uint256 _amount
    ) public {
        _registerCandidateToStream(_memberAddress, _stream, _role, _amount);
    }

    function registerMemberHarness(address _memberAddress, PublicKeyRegistration[] calldata _publicKeysRegistration)
        public
    {
        _registerMember(_memberAddress, _publicKeysRegistration);
    }

    function createCommitteeAfterApplyToStreamHarness(StreamDenomination _denomination) public {
        _createCommitteeAfterApplyToStream(_denomination);
    }

    function createCommitteeHarness(uint64 _streamId) public {
        _createCommittee(_streamId);
    }

    function shouldCreateCommitteeHarness(uint64 _streamId) public view returns (bool) {
        return shouldCreateCommittee[_streamId];
    }

    function createCommitteeWithLastCandidatesHarness(uint64 _streamId, uint256 numWatchtowers, uint256 numOperators)
        public
        returns (CommitteeMember[] memory)
    {
        // Delete any pending committee for the stream before creating a new one.
        _deletePendingCommittee(_streamId);

        // NOTE: This method is called from the pegManager, so we should not revert.
        (CommitteeMember[] memory committeeMembers,) =
            _selectCommitteeLastMembersHarness(_streamId, numWatchtowers, numOperators);

        shouldCreateCommittee[_streamId] = false;
        pendingCommittees[_streamId].createdAt = block.timestamp;
        pendingCommittees[_streamId].missingData = uint16(committeeMembers.length);

        // Initialize the committee members here.
        // No need to initialize aggregatedKey, since it will be set by the members.
        for (uint256 i = 0; i < committeeMembers.length; i++) {
            // Copy committee members from memory to storage
            pendingCommittees[_streamId].committee.members.push(committeeMembers[i]);

            // Initialize committee users pending data
            pendingCommittees[_streamId].data[committeeMembers[i].memberAddress] =
                PendingCommitteeData({inCommittee: true, aggregatedKey: bytes32(0)});
        }
        emit NewPendingCommittee(_streamId, pendingCommittees[_streamId].committee);
        return committeeMembers;
    }

    function _selectCommitteeLastMembersHarness(uint64 _streamId, uint256 numWatchtowers, uint256 numOperators)
        internal
        view
        returns (CommitteeMember[] memory, PendingCommitteeStatus)
    {
        StreamDenomination denomination = StreamDenomination(_streamId);
        address[] memory watchtowers = committeesCandidates[denomination][Role.WATCHTOWER];
        address[] memory operators = committeesCandidates[denomination][Role.OPERATOR];

        if (watchtowers.length < numWatchtowers) {
            revert("Not enough watchtower candidates");
        }

        if (operators.length < numOperators) {
            revert("Not enough operator candidates");
        }

        uint256 committeeMembersTotal = numWatchtowers + numOperators;
        uint256 committeeMembersCounter = 0;
        CommitteeMember[] memory selectedMembers = new CommitteeMember[](committeeMembersTotal);

        // Select last operators
        for (uint256 i = 0; i < numOperators; i++) {
            selectedMembers[committeeMembersCounter++] =
                CommitteeMember({memberAddress: operators[operators.length - 1 - i], role: Role.OPERATOR});
        }

        // Select last watchtowers
        for (uint256 i = 0; i < numWatchtowers; i++) {
            selectedMembers[committeeMembersCounter++] =
                CommitteeMember({memberAddress: watchtowers[watchtowers.length - 1 - i], role: Role.WATCHTOWER});
        }

        return (selectedMembers, PendingCommitteeStatus.SUCCESS);
    }

    function removeCandidatesAndUpdateBalanceHarness(
        CommitteeMember[] memory _members,
        StreamDenomination _denomination,
        uint64 _packetNumber
    ) public {
        _removeCandidatesAndUpdateBalance(_members, _denomination, _packetNumber);
    }
}
