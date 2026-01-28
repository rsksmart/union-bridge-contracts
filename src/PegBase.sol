// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {IPegBase} from "./interfaces/IPegBase.sol";
import {ProofValidator} from "./ProofValidator.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {IBitcoinManager} from "./interfaces/IBitcoinManager.sol";
import {IStreamManager} from "./interfaces/IStreamManager.sol";
import {ICommitteeRegistry} from "./interfaces/ICommitteeRegistry.sol";
import {PegStatus, StreamPosition} from "./interfaces/IPegCommonTypes.sol";
import {BaseProxy} from "./BaseProxy.sol";
import {AccessManager} from "./AccessManager.sol";

/// @title PegBase
/// @notice Abstract base contract for shared functionality between PeginManager, PegoutManager and ChallengeManager
/// @dev Contains common state variables, initialization logic, and setter functions
abstract contract PegBase is IPegBase, BaseProxy, ProofValidator, ReentrancyGuardUpgradeable {
    /// @notice Bitcoin manager contract for Bitcoin transaction validation and address generation
    IBitcoinManager public bitcoinManager;

    /// @notice Stream manager contract for managing union bridge streams and slots
    IStreamManager public streamManager;

    /// @notice Committee registry contract for managing committee and members
    ICommitteeRegistry public committeeRegistry;

    AccessManager public accessManager;

    /// @notice Initializes the base PegBase contract
    /// @param _initialOwner The initial owner of the contract
    /// @param _bridgeAddress The address of the pow-peg bridge contract
    /// @param _accessManager The access manager contract address
    /// @param _committeeRegistry The committee registry contract address
    /// @param _bitcoinManager The Bitcoin manager contract address
    /// @param _streamManager The stream manager contract address
    /// @dev This function should be called by child contracts during their initialization
    function __PegBase_init(
        address _initialOwner,
        address payable _bridgeAddress,
        address _accessManager,
        ICommitteeRegistry _committeeRegistry,
        IBitcoinManager _bitcoinManager,
        IStreamManager _streamManager
    ) internal onlyInitializing {
        // Validate that the addresses are not zero
        if (
            address(_bitcoinManager) == address(0) || address(_committeeRegistry) == address(0)
                || address(_streamManager) == address(0)
        ) {
            revert InvalidZeroAddress();
        }
        bitcoinManager = _bitcoinManager;
        committeeRegistry = _committeeRegistry;
        streamManager = _streamManager;
        accessManager = AccessManager(_accessManager);

        __BaseProxy_init(_initialOwner);
        __ProofValidator_init(_bridgeAddress, _accessManager);
        __ReentrancyGuard_init();
    }

    function _validatePegStatus(bytes32 _acceptPeginTxid, PegStatus _expectedStatus)
        internal
        view
        returns (StreamPosition memory)
    {
        StreamPosition memory streamInfo = streamManager.getStreamPosition(_acceptPeginTxid);

        if (streamInfo.pegStatus == PegStatus.NOT_REGISTERED) {
            revert PeginNotRequested(_acceptPeginTxid);
        }

        if (streamInfo.pegStatus != _expectedStatus) {
            revert InvalidPegStatus(streamInfo.pegStatus);
        }

        return streamInfo;
    }
}
