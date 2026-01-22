// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {CommitteeRegistry} from "src/CommitteeRegistry.sol";
import {Role, CommitteeMember, CommitteeRegistrySettings} from "src/interfaces/ICommitteeRegistry.sol";
import {IMemberRegistry} from "src/interfaces/IMemberRegistry.sol";
import {StreamDenomination} from "src/interfaces/IStreamManager.sol";
import {PendingCommitteeStatus, CommunicationData} from "src/interfaces/ICommitteeRegistry.sol";
import {MemberRegistryHarness} from "./MemberRegistryHarness.sol";

/// @notice Wrapper for testing CommitteeRegistry
contract CommitteeRegistryHarness is CommitteeRegistry {
    // This should be the same as in the HelperContract.sol
    uint128 constant COMMITTEE_ID_STREAM_1_COMMITTEE_1 = 206898896734299866373660992622464848465;

    MemberRegistryHarness public memberRegistryHarness;

    function initialize(
        address _initialOwner,
        IMemberRegistry _memberRegistryHarness,
        CommitteeRegistrySettings memory _settings
    ) public override initializer {
        CommitteeRegistry.initialize(_initialOwner, _memberRegistryHarness, _settings);

        memberRegistryHarness = MemberRegistryHarness(address(_memberRegistryHarness));
    }

    function selectCommittee(uint64 _denomination) public returns (CommitteeMember[] memory, PendingCommitteeStatus) {
        return memberRegistry.selectCommittee(
            _denomination, minCommitteeWatchtowers, minCommitteeOperators, committeeMemberCount
        );
    }

    function setMinCommitteeWatchtowersHarness(uint256 _minCommitteeWatchtowers) public {
        minCommitteeWatchtowers = _minCommitteeWatchtowers;
    }

    function setMinCommitteeOperatorsHarness(uint256 _minCommitteeOperators) public {
        minCommitteeOperators = _minCommitteeOperators;
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
        returns (CommitteeMember[] memory committeeMembers, uint128 committeeId)
    {
        // Delete any pending committee for the stream before creating a new one.
        _discardPendingCommittee(_streamId);

        // NOTE: This method is called from the pegManager, so we should not revert.
        (committeeMembers,) = _selectCommitteeLastMembersHarness(_streamId, numWatchtowers, numOperators);

        shouldCreateCommittee[_streamId] = false;
        committeeId = COMMITTEE_ID_STREAM_1_COMMITTEE_1; // For testing, we use a fixed committee ID.
        pendingCommittees[_streamId] = committeeId;
        committeesById[committeeId].createdAt = block.timestamp;
        committeesById[committeeId].missingData = uint16(committeeMembers.length);
        committeesById[committeeId].isPending = true;
        committeesById[committeeId].streamId = _streamId;

        // Initialize the committee members here.
        // No need to initialize aggregatedKey, since it will be set by the members.
        for (uint256 i = 0; i < committeeMembers.length; i++) {
            // Copy committee members from memory to storage
            committeesById[committeeId].members.push(committeeMembers[i]);

            // Initialize committee users pending data
            committeesData[committeeId][committeeMembers[i].memberAddress].inCommittee = true;
        }
        emit NewPendingCommittee(committeeId, committeesById[committeeId]);
    }

    /// @notice Harness function to directly access stored communication data for testing
    /// @param _denomination The stream denomination
    /// @param _memberAddress The address of the member who deposited the data
    /// @return communicationData The communication data stored by this member
    function getStoredCommunicationDataHarness(StreamDenomination _denomination, address _memberAddress)
        external
        view
        returns (CommunicationData[] memory communicationData)
    {
        uint64 streamId = uint64(_denomination);
        if (!_isInPendingCommittee(_memberAddress, _denomination)) {
            revert MemberNotInCommittee(streamId, _memberAddress);
        }

        return committeesData[pendingCommittees[streamId]][_memberAddress].communicationData;
    }

    /// @notice Harness function to directly set communication data for testing getMemberCommunicationData
    /// @param _streamId The stream ID
    /// @param _targetMemberIndex The index of the member who should receive this data
    /// @param _communicationData Array of communication data to set for each committee member
    function setCommunicationDataForMemberHarness(
        uint64 _streamId,
        uint256 _targetMemberIndex,
        CommunicationData[] memory _communicationData
    ) external {
        uint128 committeeId = pendingCommittees[_streamId];
        CommitteeMember[] storage committeeMembers = committeesById[committeeId].members;
        require(_communicationData.length == committeeMembers.length, "Invalid data length");

        // First: ensure all members have arrays of the right size
        for (uint256 i = 0; i < committeeMembers.length; i++) {
            address memberAddress = committeeMembers[i].memberAddress;
            CommunicationData[] storage memberCommData = committeesData[committeeId][memberAddress].communicationData;

            for (uint256 j = 0; j < committeeMembers.length; j++) {
                memberCommData.push();
            }
        }

        // Second: fill with the actual data
        for (uint256 i = 0; i < committeeMembers.length; i++) {
            address memberAddress = committeeMembers[i].memberAddress;
            committeesData[committeeId][memberAddress].communicationData[_targetMemberIndex] = _communicationData[i];
        }
    }

    function _selectCommitteeLastMembersHarness(uint64 _streamId, uint256 numWatchtowers, uint256 numOperators)
        internal
        returns (CommitteeMember[] memory, PendingCommitteeStatus)
    {
        StreamDenomination denomination = StreamDenomination(_streamId);
        address[] memory watchtowers = memberRegistry.getCommitteeCandidates(denomination, Role.WATCHTOWER);
        address[] memory operators = memberRegistry.getCommitteeCandidates(denomination, Role.OPERATOR);

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
            Role role = Role.OPERATOR;
            selectedMembers[committeeMembersCounter++] =
                CommitteeMember({memberAddress: operators[operators.length - 1 - i], role: role});
            memberRegistryHarness.removeLastCandidateHarness(denomination, role);
        }

        // Select last watchtowers
        for (uint256 i = 0; i < numWatchtowers; i++) {
            Role role = Role.WATCHTOWER;
            selectedMembers[committeeMembersCounter++] =
                CommitteeMember({memberAddress: watchtowers[watchtowers.length - 1 - i], role: role});
            memberRegistryHarness.removeLastCandidateHarness(denomination, role);
        }

        return (selectedMembers, PendingCommitteeStatus.SUCCESS);
    }

    function stakePreStakedCandidatesBalanceHarness(
        CommitteeMember[] memory _members,
        StreamDenomination _denomination,
        uint64 _packetNumber
    ) public {
        memberRegistry.stakePreStakedCandidatesBalance(_members, _denomination, _packetNumber);
    }
}
