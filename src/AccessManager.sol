// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {IAccessManager} from "./interfaces/IAccessManager.sol";
import {PauseManager} from "./PauseManager.sol";

/// @title AccessManager
/// @notice Manages access control for the union bridge system
/// @dev Provides access control with pause manager contracts as the authorized accounts
/// @dev Inherits from PauseManager to inherit the pause manager functionality
contract AccessManager is IAccessManager, PauseManager {
    /// @notice Initializes the AccessManager contract
    /// @dev Sets up the initial owner
    /// @dev Can only be called once during contract deployment
    /// @param _initialOwner The address that will be set as the initial owner
    function initialize(address _initialOwner) public initializer {
        __PauseManager_init(_initialOwner);
    }

    function requireCanModifyPegStatus(address _caller) external view {
        if (_caller != peginManager && _caller != pegoutManager && _caller != challengeManager) {
            revert UnauthorizedToModifyPegStatus(_caller);
        }
    }

    function requireCanCreateCommittee(address _caller) external view {
        if (_caller != peginManager) {
            revert UnauthorizedToCreateCommittee(_caller);
        }
    }

    function requireCanReleaseCommittee(address _caller) external view {
        if (_caller != pegoutManager) {
            revert UnauthorizedToReleaseCommittee(_caller);
        }
    }

    function requireCanSelectTakeOperator(address _caller) external view {
        if (_caller != pegoutManager) {
            revert UnauthorizedToSelectTakeOperator(_caller);
        }
    }

    function requireCanCreatePacket(address _caller) external view {
        if (_caller != committeeRegistry) {
            revert UnauthorizedToCreatePacket(_caller);
        }
    }

    function requireCanMintRbtc(address _caller) external view {
        if (_caller != peginManager) {
            revert UnauthorizedToMintRbtc(_caller);
        }
    }

    function requireCanBurnRbtc(address _caller) external view {
        if (_caller != pegoutManager) {
            revert UnauthorizedToBurnRbtc(_caller);
        }
    }

    function requireCanInitSignatures(address _caller) external view {
        if (_caller != peginManager && _caller != pegoutManager) {
            revert UnauthorizedToInitSignatures(_caller);
        }
    }

    function requireCanInitOperatorTakeTxids(address _caller) external view {
        if (_caller != peginManager) {
            revert UnauthorizedToInitOperatorTakeTxids(_caller);
        }
    }

    function requireCanModifyCandidatesForStream(address _caller) external view {
        if (_caller != committeeRegistry) {
            revert UnauthorizedToModifyCandidatesForStream(_caller);
        }
    }
}
