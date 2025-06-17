// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {CommitteeRegistry, CommitteeMember, PublicKeyRegistration} from "src/CommitteeRegistry.sol";
import {Role} from "src/interfaces/ICommitteeRegistry.sol";
import {StreamDenomination} from "src/interfaces/IStreamManager.sol";
import {PendingCommitteeStatus} from "src/interfaces/ICommitteeRegistry.sol";

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
}
