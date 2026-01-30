// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {IAccessManager} from "./interfaces/IAccessManager.sol";
import {PauseManager} from "./PauseManager.sol";
import {ChainIds} from "./libraries/Network.sol";

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

    /// @inheritdoc IAccessManager
    function canModifyPegStatus(address _caller) external view {
        if (_caller != peginManager && _caller != pegoutManager && _caller != challengeManager) {
            revert UnauthorizedToModifyPegStatus(_caller);
        }
    }

    /// @inheritdoc IAccessManager
    function canCreateCommittee(address _caller) external view {
        if (_caller != peginManager) {
            revert UnauthorizedToCreateCommittee(_caller);
        }
    }

    /// @inheritdoc IAccessManager
    function canReleaseCommittee(address _caller) external view {
        if (_caller != pegoutManager) {
            revert UnauthorizedToReleaseCommittee(_caller);
        }
    }

    /// @inheritdoc IAccessManager
    function canSelectTakeOperator(address _caller) external view {
        if (_caller != pegoutManager) {
            revert UnauthorizedToSelectTakeOperator(_caller);
        }
    }

    /// @inheritdoc IAccessManager
    function canCreatePacket(address _caller) external view {
        if (_caller != committeeRegistry) {
            revert UnauthorizedToCreatePacket(_caller);
        }
    }

    /// @inheritdoc IAccessManager
    function canMintRbtc(address _caller) external view {
        if (_caller != peginManager) {
            revert UnauthorizedToMintRbtc(_caller);
        }
    }

    /// @inheritdoc IAccessManager
    function canBurnRbtc(address _caller) external view {
        if (_caller != pegoutManager) {
            revert UnauthorizedToBurnRbtc(_caller);
        }
    }

    /// @inheritdoc IAccessManager
    function canInitSignatures(address _caller) external view {
        if (_caller != peginManager && _caller != pegoutManager) {
            revert UnauthorizedToInitSignatures(_caller);
        }
    }

    /// @inheritdoc IAccessManager
    function canInitOperatorTakeTxids(address _caller) external view {
        if (_caller != peginManager) {
            revert UnauthorizedToInitOperatorTakeTxids(_caller);
        }
    }

    /// @inheritdoc IAccessManager
    function canModifyCandidatesForStream(address _caller) external view {
        if (_caller != committeeRegistry) {
            revert UnauthorizedToModifyCandidatesForStream(_caller);
        }
    }

    // --- TESTNET ONLY: Force close committee functionality ---
    // TODO: Remove before mainnet deployment
    function _revertIfNotTestnet() internal view {
        if (
            block.chainid != ChainIds.RSK_TESTNET && block.chainid != ChainIds.RSK_REGTEST
                && block.chainid != ChainIds.LOCAL
        ) {
            revert TestnetOnlyFunction();
        }
    }

    function revertIfNotTestnet() external view {
        _revertIfNotTestnet();
    }

    function canForceUpdateStreamPointers(address _caller) external view {
        _revertIfNotTestnet();
        if (_caller != committeeRegistry) {
            revert UnauthorizedToInvalidateStreamPointers(_caller);
        }
    }

    function canForceReleaseCommittee(address _caller) external view {
        _revertIfNotTestnet();
        if (_caller != committeeRegistry) {
            revert UnauthorizedToForceReleaseCommittee(_caller);
        }
    }
    // --- END TESTNET ONLY ---
}
