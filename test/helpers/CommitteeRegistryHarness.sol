// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {CommitteeRegistry, CommitteeMember} from "src/CommitteeRegistry.sol";

/// @notice Wrapper for testing CommitteeRegistry
contract CommitteeRegistryHarness is CommitteeRegistry {
    function initialize(address _initialOwner) public override initializer {
        CommitteeRegistry.initialize(_initialOwner);
    }

    function selectCommittee(uint64 _denomination) public returns (CommitteeMember[] memory) {
        return _selectCommittee(_denomination);
    }
}
