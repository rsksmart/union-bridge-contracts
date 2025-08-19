// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {CommitteeRegistry, CommitteeMember} from "src/CommitteeRegistry.sol";
import {Role, UTXO} from "src/interfaces/ICommitteeRegistry.sol";
import {StreamDenomination} from "src/interfaces/IStreamManager.sol";
import {
    PendingCommitteeStatus,
    PendingCommittee,
    MemberRegistrationKeys,
    CommunicationData
} from "src/interfaces/ICommitteeRegistry.sol";

/// @notice Wrapper for testing CommitteeRegistry
contract CommitteeRegistryHarness is CommitteeRegistry {
    function initialize(address _initialOwner) internal override initializer {
        //replaced by Review_public_methods
        // public override initializer {
        CommitteeRegistry.initialize(_initialOwner);
    }

    function selectCommittee(uint64 _denomination) public returns (CommitteeMember[] memory, PendingCommitteeStatus) {
        return _selectCommittee(_denomination);
    }

    function registerCandidateToStreamHarness(
        address _memberAddress,
        StreamDenomination _stream,
        Role _role,
        uint256 _amount,
        UTXO calldata _fundingUTXO
    ) public {
        _registerCandidateToStream(_memberAddress, _stream, _role, _amount, _fundingUTXO);
    }

    function registerMemberHarness(address _memberAddress, MemberRegistrationKeys calldata _publicKeysRegistration)
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
            pendingCommittees[_streamId].data[committeeMembers[i].memberAddress].inCommittee = true;
        }
        emit NewPendingCommittee(_streamId, pendingCommittees[_streamId].committee);
        return committeeMembers;
    }

    /// @notice Harness function to directly access stored communication data for testing
    /// @param _streamId The stream ID
    /// @param _memberAddress The address of the member who deposited the data
    /// @return communicationData The communication data stored by this member
    function getStoredCommunicationDataHarness(uint64 _streamId, address _memberAddress)
        external
        view
        returns (CommunicationData[] memory communicationData)
    {
        PendingCommittee storage pendingCommittee = _getPendingCommittee(_streamId);

        if (!_isInPendingCommittee(_memberAddress, _streamId)) {
            revert MemberNotInCommittee(_streamId, _memberAddress);
        }

        return pendingCommittee.data[_memberAddress].communicationData;
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
        CommitteeMember[] storage committeeMembers = pendingCommittees[_streamId].committee.members;
        require(_communicationData.length == committeeMembers.length, "Invalid data length");

        // First: ensure all members have arrays of the right size
        for (uint256 i = 0; i < committeeMembers.length; i++) {
            address memberAddress = committeeMembers[i].memberAddress;
            CommunicationData[] storage memberCommData =
                pendingCommittees[_streamId].data[memberAddress].communicationData;

            for (uint256 j = 0; j < committeeMembers.length; j++) {
                memberCommData.push();
            }
        }

        // Second: fill with the actual data
        for (uint256 i = 0; i < committeeMembers.length; i++) {
            address memberAddress = committeeMembers[i].memberAddress;
            pendingCommittees[_streamId].data[memberAddress].communicationData[_targetMemberIndex] =
                _communicationData[i];
        }
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

        for (uint256 i = 0; i < numOperators; i++) {
            // Select last operators
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
