// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {MemberRegistry} from "src/MemberRegistry.sol";
import {Role, UTXO, MemberRegistrationKeys} from "src/interfaces/ICommitteeRegistry.sol";
import {IStreamManager, StreamDenomination} from "src/interfaces/IStreamManager.sol";
import {IAccessManager} from "src/interfaces/IAccessManager.sol";
import {IBridge} from "src/interfaces/IBridge.sol";

/// @notice Wrapper for testing MemberRegistry
contract MemberRegistryHarness is MemberRegistry {
    function initialize(
        address _initialOwner,
        IAccessManager _accessManager,
        IBridge _bridge,
        IStreamManager _streamManager
    ) public override initializer {
        MemberRegistry.initialize(_initialOwner, _accessManager, _bridge, _streamManager);
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

    function removeLastCandidateHarness(StreamDenomination _denomination, Role _role) public {
        address[] storage candidates = committeesCandidates[_denomination][_role];
        candidates.pop();
    }

    /// @notice Forcefully sets a member's covenant key for testing purposes
    /// @dev Bypasses all validation - USE ONLY IN TESTS
    /// @param _memberAddress The member whose covenant key to set
    /// @param _covenantKey The covenant public key (x-coordinate only)
    function setMemberCovenantKeyHarness(address _memberAddress, bytes32 _covenantKey) public {
        members[_memberAddress].publicKeys.covenantPubKey = _covenantKey;
    }
}
