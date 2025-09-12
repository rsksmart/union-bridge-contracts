// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {MemberRegistry} from "src/MemberRegistry.sol";
import {Role, UTXO, MemberRegistrationKeys} from "src/interfaces/ICommitteeRegistry.sol";
import {StreamDenomination} from "src/interfaces/IStreamManager.sol";

/// @notice Wrapper for testing MemberRegistry
contract MemberRegistryHarness is MemberRegistry {
    function initialize(address _initialOwner) public override initializer {
        MemberRegistry.initialize(_initialOwner);
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
}
