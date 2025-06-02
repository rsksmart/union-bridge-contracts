// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {CommitteeRegistry, CommitteeMember} from "src/CommitteeRegistry.sol";
import {Role} from "src/interfaces/ICommitteeRegistry.sol";
import {StreamDenomination} from "src/interfaces/IStreamManager.sol";

/// @notice Wrapper for testing CommitteeRegistry
contract CommitteeRegistryHarness is CommitteeRegistry {
    function initialize(address _initialOwner) public override initializer {
        CommitteeRegistry.initialize(_initialOwner);
    }

    function selectCommittee(uint64 _denomination) public view returns (CommitteeMember[] memory) {
        return _selectCommittee(_denomination);
    }

    function registerCandidateToStream(address _memberAddress, StreamDenomination _stream, Role _role, uint256 _amount)
        public
    {
        _registerCandidateToStream(_memberAddress, _stream, _role, _amount);
    }

    function registerMember(bytes32 _publicKey) public {
        _registerMember(_publicKey);
    }
}
